const db = require('../config/db');

// 发起协助请求
exports.requestSession = async (req, res) => {
  try {
    const { assistant_user_id, request_description } = req.body;
    if (!assistant_user_id) {
      return res.status(400).json({ success: false, message: '请选择协助者' });
    }

    // 验证绑定关系
    const [relationship] = await db.query(
      'SELECT id FROM family_relationships WHERE elderly_user_id = ? AND family_user_id = ?',
      [req.user.id, assistant_user_id]
    );
    if (relationship.length === 0) {
      return res.status(400).json({ success: false, message: '只能向已绑定的家人发起协助' });
    }

    const [result] = await db.query(
      'INSERT INTO remote_sessions (elderly_user_id, assistant_user_id, status, request_description) VALUES (?, ?, ?, ?)',
      [req.user.id, assistant_user_id, 'requested', request_description || '']
    );

    res.json({ success: true, data: { session_id: result.insertId } });
  } catch (err) {
    console.error('RequestSession error:', err);
    res.status(500).json({ success: false, message: '发起协助失败' });
  }
};

// 获取会话列表（支持分页）
exports.getSessions = async (req, res) => {
  try {
    const { page, pageSize } = req.query;
    let sql, countSql, params, countParams;

    if (req.user.user_type === 'elderly') {
      sql = `SELECT rs.*, u.name as assistant_name
             FROM remote_sessions rs
             JOIN users u ON rs.assistant_user_id = u.id
             WHERE rs.elderly_user_id = ?`;
      countSql = 'SELECT COUNT(*) as total FROM remote_sessions WHERE elderly_user_id = ?';
      params = [req.user.id];
      countParams = [req.user.id];
    } else {
      sql = `SELECT rs.*, u.name as elderly_name
             FROM remote_sessions rs
             JOIN users u ON rs.elderly_user_id = u.id
             WHERE rs.assistant_user_id = ?`;
      countSql = 'SELECT COUNT(*) as total FROM remote_sessions WHERE assistant_user_id = ?';
      params = [req.user.id];
      countParams = [req.user.id];
    }

    sql += ' ORDER BY rs.created_at DESC';

    // 分页：当传入 page 和 pageSize 时生效
    if (page && pageSize) {
      const pageNum = Math.max(1, parseInt(page));
      const size = Math.min(Math.max(1, parseInt(pageSize)), 100);
      const offset = (pageNum - 1) * size;
      sql += ' LIMIT ? OFFSET ?';
      params.push(size, offset);

      const [[countResult]] = await db.query(countSql, countParams);
      const total = countResult.total;
      const [sessions] = await db.query(sql, params);

      return res.json({
        success: true,
        data: sessions,
        pagination: {
          page: pageNum,
          pageSize: size,
          total,
          totalPages: Math.ceil(total / size),
        },
      });
    }

    // 不分页：保持向后兼容
    const [sessions] = await db.query(sql, params);
    res.json({ success: true, data: sessions });
  } catch (err) {
    console.error('GetSessions error:', err);
    res.status(500).json({ success: false, message: '获取会话列表失败' });
  }
};

// 更新会话状态
exports.updateStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['active', 'completed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: '无效的状态' });
    }

    const updates = { status };
    if (status === 'active') updates.started_at = new Date();
    if (status === 'completed' || status === 'cancelled') updates.ended_at = new Date();

    const setClauses = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    const values = Object.values(updates);
    values.push(req.params.id);

    const [result] = await db.query(
      `UPDATE remote_sessions SET ${setClauses} WHERE id = ? AND (elderly_user_id = ? OR assistant_user_id = ?)`,
      [...values, req.user.id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '会话不存在' });
    }

    res.json({ success: true, message: '状态更新成功' });
  } catch (err) {
    console.error('UpdateStatus error:', err);
    res.status(500).json({ success: false, message: '更新会话状态失败' });
  }
};