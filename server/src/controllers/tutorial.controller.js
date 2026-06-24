const db = require('../config/db');
const logger = require('../utils/logger');

// 获取教程列表（支持分页）
exports.getAll = async (req, res) => {
  try {
    const { category, page, pageSize } = req.query;
    let sql = 'SELECT id, title, description, category, difficulty_level, image_url, steps FROM tutorials WHERE is_active = 1';
    let countSql = 'SELECT COUNT(*) as total FROM tutorials WHERE is_active = 1';
    const params = [];
    const countParams = [];

    if (category) {
      sql += ' AND category = ?';
      countSql += ' AND category = ?';
      params.push(category);
      countParams.push(category);
    }

    sql += ' ORDER BY created_at DESC';

    // 分页：当传入 page 和 pageSize 时生效
    if (page && pageSize) {
      const pageNum = Math.max(1, parseInt(page));
      const size = Math.min(Math.max(1, parseInt(pageSize)), 100);
      const offset = (pageNum - 1) * size;
      sql += ' LIMIT ? OFFSET ?';
      params.push(size, offset);

      const [[countResult]] = await db.query(countSql, countParams);
      const total = countResult.total;
      const [tutorials] = await db.query(sql, params);

      const result = tutorials.map(t => ({
        ...t,
        steps: typeof t.steps === 'string' ? JSON.parse(t.steps) : t.steps
      }));

      return res.json({
        success: true,
        data: result,
        pagination: {
          page: pageNum,
          pageSize: size,
          total,
          totalPages: Math.ceil(total / size),
        },
      });
    }

    // 不分页：保持向后兼容
    const [tutorials] = await db.query(sql, params);
    const result = tutorials.map(t => ({
      ...t,
      steps: typeof t.steps === 'string' ? JSON.parse(t.steps) : t.steps
    }));

    res.json({ success: true, data: result });
  } catch (err) {
    logger.error('GetTutorials error', { error: err.message });
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
    logger.error('GetTutorial error', { error: err.message });
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
    logger.error('CreateTutorial error', { error: err.message });
    res.status(500).json({ success: false, message: '创建教程失败' });
  }
};

// 更新教程
exports.update = async (req, res) => {
  try {
    const { title, description, category, difficulty_level, image_url, steps } = req.body;

    // 输入校验
    if (!title || !category || !steps) {
      return res.status(400).json({ success: false, message: '标题、分类和步骤不能为空' });
    }
    const validLevels = ['beginner', 'intermediate', 'advanced'];
    if (difficulty_level && !validLevels.includes(difficulty_level)) {
      return res.status(400).json({ success: false, message: '难度级别无效' });
    }

    const [result] = await db.query(
      'UPDATE tutorials SET title=?, description=?, category=?, difficulty_level=?, image_url=?, steps=? WHERE id=? AND is_active = 1',
      [title, description || '', category, difficulty_level || 'beginner', image_url || '', JSON.stringify(steps), req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '教程不存在' });
    }

    res.json({ success: true, message: '更新成功' });
  } catch (err) {
    logger.error('UpdateTutorial error', { error: err.message });
    res.status(500).json({ success: false, message: '更新教程失败' });
  }
};

// 删除教程（软删除：标记 is_active = 0）
exports.remove = async (req, res) => {
  try {
    const [result] = await db.query(
      'UPDATE tutorials SET is_active = 0 WHERE id = ? AND is_active = 1',
      [req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: '教程不存在' });
    }
    res.json({ success: true, message: '删除成功' });
  } catch (err) {
    logger.error('DeleteTutorial error', { error: err.message });
    res.status(500).json({ success: false, message: '删除教程失败' });
  }
};