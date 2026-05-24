const db = require('../config/db');

// 通过手机号绑定家人
exports.bindFamily = async (req, res) => {
  try {
    const { phone, relationship } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, message: '请输入家人手机号' });
    }

    // 查找家人用户
    const [familyUsers] = await db.query('SELECT id, name, user_type FROM users WHERE phone = ?', [phone]);
    if (familyUsers.length === 0) {
      return res.status(404).json({ success: false, message: '未找到该用户' });
    }

    const familyUser = familyUsers[0];
    if (familyUser.id === req.user.id) {
      return res.status(400).json({ success: false, message: '不能绑定自己' });
    }

    // 确定老人和家人的 ID
    let elderlyUserId, familyUserId;
    if (req.user.user_type === 'elderly') {
      elderlyUserId = req.user.id;
      familyUserId = familyUser.id;
    } else if (req.user.user_type === 'family') {
      if (familyUser.user_type !== 'elderly') {
        return res.status(400).json({ success: false, message: '只能绑定老人用户' });
      }
      elderlyUserId = familyUser.id;
      familyUserId = req.user.id;
    } else {
      return res.status(400).json({ success: false, message: '管理员不支持绑定' });
    }

    // 检查是否已绑定
    const [existing] = await db.query(
      'SELECT id FROM family_relationships WHERE elderly_user_id = ? AND family_user_id = ?',
      [elderlyUserId, familyUserId]
    );
    if (existing.length > 0) {
      return res.status(400).json({ success: false, message: '已经绑定过了' });
    }

    await db.query(
      'INSERT INTO family_relationships (elderly_user_id, family_user_id, relationship) VALUES (?, ?, ?)',
      [elderlyUserId, familyUserId, relationship || 'child']
    );

    res.json({ success: true, message: '绑定成功' });
  } catch (err) {
    console.error('BindFamily error:', err);
    res.status(500).json({ success: false, message: '绑定失败' });
  }
};

// 获取已绑定的家人列表
exports.getFamily = async (req, res) => {
  try {
    let sql, params;
    if (req.user.user_type === 'elderly') {
      sql = `SELECT u.id, u.name, u.phone, u.user_type, fr.relationship, fr.id as relationship_id
             FROM family_relationships fr
             JOIN users u ON fr.family_user_id = u.id
             WHERE fr.elderly_user_id = ?`;
      params = [req.user.id];
    } else {
      sql = `SELECT u.id, u.name, u.phone, u.user_type, fr.relationship, fr.id as relationship_id
             FROM family_relationships fr
             JOIN users u ON fr.elderly_user_id = u.id
             WHERE fr.family_user_id = ?`;
      params = [req.user.id];
    }

    const [family] = await db.query(sql, params);
    res.json({ success: true, data: family });
  } catch (err) {
    console.error('GetFamily error:', err);
    res.status(500).json({ success: false, message: '获取家人列表失败' });
  }
};

// 解除绑定
exports.unbindFamily = async (req, res) => {
  try {
    const [result] = await db.query(
      'DELETE FROM family_relationships WHERE id = ? AND (elderly_user_id = ? OR family_user_id = ?)',
      [req.params.id, req.user.id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '绑定关系不存在' });
    }

    res.json({ success: true, message: '解除绑定成功' });
  } catch (err) {
    console.error('UnbindFamily error:', err);
    res.status(500).json({ success: false, message: '解除绑定失败' });
  }
};

// 更新用户设置
exports.updateSettings = async (req, res) => {
  try {
    const { name, font_size } = req.body;
    const updates = [];
    const params = [];

    if (name) { updates.push('name = ?'); params.push(name); }
    if (font_size) { updates.push('font_size = ?'); params.push(font_size); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: '没有要更新的内容' });
    }

    params.push(req.user.id);
    await db.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);

    res.json({ success: true, message: '更新成功' });
  } catch (err) {
    console.error('UpdateSettings error:', err);
    res.status(500).json({ success: false, message: '更新失败' });
  }
};

// 更新头像
exports.updateAvatar = async (req, res) => {
  try {
    const { avatar_url } = req.body;
    if (!avatar_url) {
      return res.status(400).json({ success: false, message: '请提供头像地址' });
    }

    await db.query('UPDATE users SET avatar_url = ? WHERE id = ?', [avatar_url, req.user.id]);
    res.json({ success: true, data: { avatar_url }, message: '头像更新成功' });
  } catch (err) {
    console.error('UpdateAvatar error:', err);
    res.status(500).json({ success: false, message: '头像更新失败' });
  }
};
