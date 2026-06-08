const db = require('../config/db');

/**
 * 安全服务 - 诈骗检测和风险预警
 */

// 诈骗关键词库
const FRAUD_KEYWORDS = [
  // 金融诈骗
  '转账', '汇款', '验证码', '银行卡', '密码', '安全账户',
  '中奖', '退税', '补贴', '贷款', '信用卡', '刷单',
  // 冒充身份
  '公检法', '警察', '法院', '检察院', '公安局',
  '客服', '快递', '银行工作人员',
  // 紧急恐吓
  '涉嫌', '违法', '犯罪', '冻结', '逮捕', '通缉',
  '紧急', '立即', '马上', '限时',
  // 利诱
  '免费', '返利', '红包', '兼职', '日赚', '高回报',
];

// 可疑链接模式
const SUSPICIOUS_LINK_PATTERNS = [
  /https?:\/\/[^\s]+\.(tk|ml|ga|cf|gq)\b/i,  // 免费域名
  /https?:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/,  // IP 地址链接
  /https?:\/\/[^\s]*login[^\s]*\.(?!com|cn|org)/i,  // 仿冒登录页
];

// 支付风险规则
const PAYMENT_RISK_RULES = {
  singleLimit: 5000,      // 单笔限额
  dailyLimit: 20000,       // 日限额
  maxTimesPerDay: 10,      // 每日最大次数
  highRiskHourStart: 23,   // 高风险时段开始
  highRiskHourEnd: 6,      // 高风险时段结束
};

/**
 * 检测文本中的诈骗风险
 * @param {string} text - 待检测文本
 * @param {number} userId - 用户 ID
 * @returns {Object} 检测结果
 */
async function detectFraud(text, userId) {
  const matchedKeywords = FRAUD_KEYWORDS.filter(kw => text.includes(kw));
  const matchedLinks = SUSPICIOUS_LINK_PATTERNS.filter(pattern => pattern.test(text));

  const risks = [];

  if (matchedKeywords.length >= 3) {
    risks.push({
      type: 'fraud_detected',
      severity: 'high',
      description: `检测到多个诈骗关键词: ${matchedKeywords.join('、')}`,
    });
  } else if (matchedKeywords.length >= 1) {
    risks.push({
      type: 'fraud_detected',
      severity: 'medium',
      description: `检测到可疑关键词: ${matchedKeywords.join('、')}`,
    });
  }

  if (matchedLinks.length > 0) {
    risks.push({
      type: 'suspicious_link',
      severity: 'high',
      description: '检测到可疑链接',
    });
  }

  // 记录安全事件
  for (const risk of risks) {
    await logSecurityEvent(userId, risk.type, risk.severity, risk.description, {
      keywords: matchedKeywords,
      textLength: text.length,
    });
  }

  return {
    hasRisk: risks.length > 0,
    risks,
    matchedKeywords,
    hasSuspiciousLinks: matchedLinks.length > 0,
  };
}

/**
 * 检测支付风险
 * @param {number} amount - 支付金额
 * @param {number} userId - 用户 ID
 * @returns {Object} 检测结果
 */
async function detectPaymentRisk(amount, userId) {
  const risks = [];
  const now = new Date();
  const hour = now.getHours();

  // 单笔限额检查
  if (amount > PAYMENT_RISK_RULES.singleLimit) {
    risks.push({
      type: 'payment_attempt',
      severity: 'high',
      description: `单笔支付金额 ${amount} 元超过限额 ${PAYMENT_RISK_RULES.singleLimit} 元`,
    });
  }

  // 高风险时段检查
  if (hour >= PAYMENT_RISK_RULES.highRiskHourStart || hour < PAYMENT_RISK_RULES.highRiskHourEnd) {
    risks.push({
      type: 'payment_attempt',
      severity: 'medium',
      description: `深夜时段 (${hour}:00) 大额支付`,
    });
  }

  // 今日支付次数和总额检查
  try {
    const [rows] = await db.query(
      `SELECT COUNT(*) as count, COALESCE(SUM(CAST(JSON_EXTRACT(metadata, '$.amount') AS DECIMAL)), 0) as total
       FROM security_events
       WHERE user_id = ? AND event_type = 'payment_attempt'
       AND DATE(created_at) = CURDATE()`,
      [userId]
    );

    const todayCount = rows[0].count;
    const todayTotal = rows[0].total;

    if (todayCount >= PAYMENT_RISK_RULES.maxTimesPerDay) {
      risks.push({
        type: 'payment_attempt',
        severity: 'high',
        description: `今日支付次数已达 ${todayCount} 次，超过限制`,
      });
    }

    if (todayTotal + amount > PAYMENT_RISK_RULES.dailyLimit) {
      risks.push({
        type: 'payment_attempt',
        severity: 'critical',
        description: `今日累计支付将超过日限额 ${PAYMENT_RISK_RULES.dailyLimit} 元`,
      });
    }
  } catch (err) {
    console.error('Payment risk check error:', err);
  }

  // 记录安全事件
  for (const risk of risks) {
    await logSecurityEvent(userId, risk.type, risk.severity, risk.description, {
      amount,
      hour,
    });
  }

  return {
    hasRisk: risks.length > 0,
    risks,
    allowed: risks.filter(r => r.severity === 'critical').length === 0,
  };
}

/**
 * 记录安全事件
 */
async function logSecurityEvent(userId, eventType, severity, description, metadata = {}) {
  try {
    await db.query(
      `INSERT INTO security_events (user_id, event_type, severity, description, metadata)
       VALUES (?, ?, ?, ?, ?)`,
      [userId, eventType, severity, description, JSON.stringify(metadata)]
    );
  } catch (err) {
    console.error('Log security event error:', err);
  }
}

/**
 * 获取用户的安全事件列表
 */
async function getSecurityEvents(userId, { page = 1, pageSize = 20, severity } = {}) {
  try {
    let whereClause = 'WHERE user_id = ?';
    const params = [userId];

    if (severity) {
      whereClause += ' AND severity = ?';
      params.push(severity);
    }

    const countSql = `SELECT COUNT(*) as total FROM security_events ${whereClause}`;
    const [[countResult]] = await db.query(countSql, params);
    const total = countResult.total;

    const offset = (page - 1) * pageSize;
    params.push(pageSize, offset);

    const [events] = await db.query(
      `SELECT * FROM security_events ${whereClause} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      params
    );

    return {
      events,
      pagination: {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
      },
    };
  } catch (err) {
    console.error('Get security events error:', err);
    throw err;
  }
}

/**
 * 标记安全事件为已解决
 */
async function resolveSecurityEvent(eventId, resolvedBy) {
  try {
    const [result] = await db.query(
      `UPDATE security_events SET is_resolved = TRUE, resolved_at = NOW(), resolved_by = ? WHERE id = ?`,
      [resolvedBy, eventId]
    );
    return result.affectedRows > 0;
  } catch (err) {
    console.error('Resolve security event error:', err);
    throw err;
  }
}

/**
 * 获取安全概览统计
 */
async function getSecurityStats(userId) {
  try {
    const [rows] = await db.query(
      `SELECT
        COUNT(*) as total_events,
        SUM(CASE WHEN is_resolved = FALSE THEN 1 ELSE 0 END) as unresolved,
        SUM(CASE WHEN severity = 'critical' AND is_resolved = FALSE THEN 1 ELSE 0 END) as critical_unresolved,
        SUM(CASE WHEN severity = 'high' AND is_resolved = FALSE THEN 1 ELSE 0 END) as high_unresolved,
        SUM(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 ELSE 0 END) as last_7_days
       FROM security_events WHERE user_id = ?`,
      [userId]
    );
    return rows[0];
  } catch (err) {
    console.error('Get security stats error:', err);
    throw err;
  }
}

module.exports = {
  detectFraud,
  detectPaymentRisk,
  logSecurityEvent,
  getSecurityEvents,
  resolveSecurityEvent,
  getSecurityStats,
};
