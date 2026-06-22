const securityService = require('../services/securityService');

/**
 * 检测诈骗风险
 */
exports.checkFraud = async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) {
      return res.status(400).json({ success: false, message: '请提供待检测文本' });
    }

    const result = await securityService.detectFraud(text, req.user.id);
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('CheckFraud error:', err);
    res.status(500).json({ success: false, message: '检测失败' });
  }
};

/**
 * 检测支付风险
 */
exports.checkPayment = async (req, res) => {
  try {
    const { amount } = req.body;
    if (!amount || amount <= 0) {
      return res.status(400).json({ success: false, message: '请提供有效的支付金额' });
    }

    const result = await securityService.detectPaymentRisk(amount, req.user.id);
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('CheckPayment error:', err);
    res.status(500).json({ success: false, message: '检测失败' });
  }
};

/**
 * 获取安全事件列表
 */
exports.getEvents = async (req, res) => {
  try {
    const { page, pageSize, severity } = req.query;
    const result = await securityService.getSecurityEvents(req.user.id, {
      page: parseInt(page) || 1,
      pageSize: parseInt(pageSize) || 20,
      severity,
    });
    res.json({ success: true, data: result.events, pagination: result.pagination });
  } catch (err) {
    console.error('GetEvents error:', err);
    res.status(500).json({ success: false, message: '获取安全事件失败' });
  }
};

/**
 * 标记安全事件为已解决
 */
exports.resolveEvent = async (req, res) => {
  try {
    const resolved = await securityService.resolveSecurityEvent(req.params.id, req.user.id);
    if (!resolved) {
      return res.status(404).json({ success: false, message: '事件不存在' });
    }
    res.json({ success: true, message: '已标记为已解决' });
  } catch (err) {
    console.error('ResolveEvent error:', err);
    res.status(500).json({ success: false, message: '操作失败' });
  }
};

/**
 * 获取安全概览统计
 */
exports.getStats = async (req, res) => {
  try {
    const stats = await securityService.getSecurityStats(req.user.id);
    res.json({ success: true, data: stats });
  } catch (err) {
    console.error('GetStats error:', err);
    res.status(500).json({ success: false, message: '获取统计失败' });
  }
};
