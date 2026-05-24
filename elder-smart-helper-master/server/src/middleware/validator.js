const { body, param, query, validationResult } = require('express-validator');

/**
 * 验证结果检查中间件
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const messages = errors.array().map(e => e.msg);
    return res.status(400).json({ success: false, message: messages[0] });
  }
  next();
}

// ---- 用户认证校验 ----

const registerRules = [
  body('phone')
    .trim().notEmpty().withMessage('请输入手机号')
    .matches(/^1[3-9]\d{9}$/).withMessage('手机号格式不正确'),
  body('password')
    .isLength({ min: 6, max: 20 }).withMessage('密码长度应为6-20位'),
  body('name')
    .trim().notEmpty().withMessage('请输入姓名')
    .isLength({ max: 50 }).withMessage('姓名不能超过50个字符'),
  body('user_type')
    .isIn(['elderly', 'family', 'admin']).withMessage('用户类型无效'),
  validate
];

const loginRules = [
  body('phone')
    .trim().notEmpty().withMessage('请输入手机号'),
  body('password')
    .notEmpty().withMessage('请输入密码'),
  validate
];

const changePasswordRules = [
  body('old_password').notEmpty().withMessage('请输入旧密码'),
  body('new_password')
    .isLength({ min: 6, max: 20 }).withMessage('新密码长度应为6-20位'),
  validate
];

// ---- 教程校验 ----

const tutorialRules = [
  body('title').trim().notEmpty().withMessage('请输入教程标题'),
  body('category').isIn(['basic', 'communication', 'payment', 'entertainment', 'utility']).withMessage('教程分类无效'),
  body('steps').isArray({ min: 1 }).withMessage('请添加至少一个步骤'),
  validate
];

const tutorialIdRule = [
  param('id').isInt({ min: 1 }).withMessage('教程ID无效'),
  validate
];

// ---- 用户绑定校验 ----

const bindFamilyRules = [
  body('phone')
    .trim().notEmpty().withMessage('请输入家人手机号')
    .matches(/^1[3-9]\d{9}$/).withMessage('手机号格式不正确'),
  body('relationship')
    .optional()
    .isIn(['child', 'spouse', 'relative', 'friend', 'caregiver']).withMessage('关系类型无效'),
  validate
];

const familyIdRule = [
  param('id').isInt({ min: 1 }).withMessage('绑定关系ID无效'),
  validate
];

// ---- 用户设置校验 ----

const updateSettingsRules = [
  body('name').optional().isLength({ max: 50 }).withMessage('姓名不能超过50个字符'),
  body('font_size').optional().isIn(['small', 'medium', 'large', 'xlarge']).withMessage('字体大小无效'),
  validate
];

// ---- 远程协助校验 ----

const requestSessionRules = [
  body('assistant_user_id').isInt({ min: 1 }).withMessage('请选择协助者'),
  body('request_description').optional().isLength({ max: 500 }).withMessage('描述不能超过500个字符'),
  validate
];

const updateStatusRules = [
  param('id').isInt({ min: 1 }).withMessage('会话ID无效'),
  body('status').isIn(['active', 'completed', 'cancelled']).withMessage('会话状态无效'),
  validate
];

module.exports = {
  registerRules,
  loginRules,
  changePasswordRules,
  tutorialRules,
  tutorialIdRule,
  bindFamilyRules,
  familyIdRule,
  updateSettingsRules,
  requestSessionRules,
  updateStatusRules,
};
