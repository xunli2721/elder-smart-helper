const db = require('../config/db');

// 获取教程列表
exports.getAll = async (req, res) => {
  try {
    const { category } = req.query;
    let sql = 'SELECT id, title, description, category, difficulty_level, image_url, steps FROM tutorials WHERE is_active = 1';
    const params = [];

    if (category) {
      sql += ' AND category = ?';
      params.push(category);
    }

    sql += ' ORDER BY created_at DESC';
    const [tutorials] = await db.query(sql, params);

    // 解析 steps JSON
    const result = tutorials.map(t => ({
      ...t,
      steps: typeof t.steps === 'string' ? JSON.parse(t.steps) : t.steps
    }));

    res.json({ success: true, data: result });
  } catch (err) {
    console.error('GetTutorials error:', err);
    res.status(500).json({ success: false, message: '获取教程失败' });
  }
};

// 获取教程详情
exports.getById = async (req, res) => {
  try {
    const [tutorials] = await db.query(
      'SELECT id, title, description, category, difficulty_level, image_url, steps FROM tutorials WHERE id = ? AND is_active = 1',
      [req.params.id]
    );
    if (tutorials.length === 0) {
      return res.status(404).json({ success: false, message: '教程不存在' });
    }

    const tutorial = tutorials[0];
    tutorial.steps = typeof tutorial.steps === 'string' ? JSON.parse(tutorial.steps) : tutorial.steps;

    res.json({ success: true, data: tutorial });
  } catch (err) {
    console.error('GetTutorial error:', err);
    res.status(500).json({ success: false, message: '获取教程失败' });
  }
};

// 创建教程
exports.create = async (req, res) => {
  try {
    const { title, description, category, difficulty_level, image_url, steps } = req.body;
    if (!title || !category || !steps) {
      return res.status(400).json({ success: false, message: '请填写完整信息' });
    }

    const [result] = await db.query(
      'INSERT INTO tutorials (title, description, category, difficulty_level, image_url, steps) VALUES (?, ?, ?, ?, ?, ?)',
      [title, description || '', category, difficulty_level || 'beginner', image_url || '', JSON.stringify(steps)]
    );

    res.json({ success: true, data: { id: result.insertId } });
  } catch (err) {
    console.error('CreateTutorial error:', err);
    res.status(500).json({ success: false, message: '创建教程失败' });
  }
};

// 更新教程
exports.update = async (req, res) => {
  try {
    const { title, description, category, difficulty_level, image_url, steps } = req.body;
    const [result] = await db.query(
      'UPDATE tutorials SET title=?, description=?, category=?, difficulty_level=?, image_url=?, steps=? WHERE id=?',
      [title, description, category, difficulty_level, image_url, JSON.stringify(steps), req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '教程不存在' });
    }

    res.json({ success: true, message: '更新成功' });
  } catch (err) {
    console.error('UpdateTutorial error:', err);
    res.status(500).json({ success: false, message: '更新教程失败' });
  }
};

// 删除教程
exports.remove = async (req, res) => {
  try {
    const [result] = await db.query('DELETE FROM tutorials WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '教程不存在' });
    }
    res.json({ success: true, message: '删除成功' });
  } catch (err) {
    console.error('DeleteTutorial error:', err);
    res.status(500).json({ success: false, message: '删除教程失败' });
  }
};
