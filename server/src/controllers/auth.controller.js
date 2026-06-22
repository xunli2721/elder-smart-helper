const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { JWT_SECRET } = require('../middleware/auth');

// 注册
exports.register = async (req, res) => {
  try {
    const { phone, password, name, user_type } = req.body;

    // 字段完整性校验
    if (!phone || !password || !name || !user_type) {
      return res.status(400).json({ success: false, message: '请填写完整信息' });
    }

    // 手机号格式校验（1开头的 11 位数字）
    if (!/^1\d{10}$/.test(phone)) {
      return res.status(400).json({ success: false, message: '手机号格式不正确' });
    }

    // 密码长度校验
    if (password.length < 6 || password.length > 20) {
      return res.status(400).json({ success: false, message: '密码长度应为 6-20 位' });
    }

    // 姓名长度校验
    if (name.trim().length < 2 || name.trim().length > 20) {
      return res.status(400).json({ success: false, message: '姓名长度应为 2-20 个字符' });
    }

    // 角色白名单校验
    const allowedTypes = ['elderly', 'family'];
    if (!allowedTypes.includes(user_type)) {
      return res.status(400).json({ success: false, message: '无效的用户类型' });
    }

    const [existing] = await db.query('SELECT id FROM users WHERE phone = ?', [phone]);
    if (existing.length > 0) {
      return res.status(400).json({ success: false, message: '该手机号已注册' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await db.query(
      'INSERT INTO users (phone, password, name, user_type) VALUES (?, ?, ?, ?)',
      [phone, hashedPassword, name.trim(), user_type]
    );

    const token = jwt.sign({ id: result.insertId, phone, user_type }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ success: true, data: { token, user: { id: result.insertId, phone, name: name.trim(), user_type } } });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ success: false, message: '注册失败' });
  }
};

// 登录
exports.login = async (req, res) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) {
      return res.status(400).json({ success: false, message: '请输入手机号和密码' });
    }

    const [users] = await db.query('SELECT * FROM users WHERE phone = ?', [phone]);
    if (users.length === 0) {
      return res.status(400).json({ success: false, message: '用户不存在' });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: '密码错误' });
    }

    const token = jwt.sign({ id: user.id, phone: user.phone, user_type: user.user_type }, JWT_SECRET, { expiresIn: '7d' });
    res.json({
      success: true,
      data: {
        token,
        user: { id: user.id, phone: user.phone, name: user.name, user_type: user.user_type, font_size: user.font_size }
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: '登录失败' });
  }
};

// 获取当前用户信息
exports.getProfile = async (req, res) => {
  try {
    const [users] = await db.query('SELECT id, phone, name, user_type, font_size, created_at FROM users WHERE id = ?', [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }
    res.json({ success: true, data: users[0] });
  } catch (err) {
    console.error('GetProfile error:', err);
    res.status(500).json({ success: false, message: '获取信息失败' });
  }
};