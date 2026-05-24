const express = require('express');
const router = express.Router();
const tutorialController = require('../controllers/tutorial.controller');
const { verifyToken } = require('../middleware/auth');
const requireAdmin = require('../middleware/admin');
const { tutorialRules, tutorialIdRule } = require('../middleware/validator');
const upload = require('../middleware/upload');

// 公开接口
router.get('/', tutorialController.getAll);
router.get('/:id', tutorialIdRule, tutorialController.getById);

// 管理接口（需登录 + 管理员权限）
router.post('/', verifyToken, requireAdmin, tutorialRules, tutorialController.create);
router.put('/:id', verifyToken, requireAdmin, tutorialIdRule, tutorialRules, tutorialController.update);
router.delete('/:id', verifyToken, requireAdmin, tutorialIdRule, tutorialController.remove);

// 图片上传
router.post('/upload-image', verifyToken, requireAdmin, upload.single('image'), tutorialController.uploadImage);

// 增加浏览量
router.post('/:id/view', tutorialIdRule, tutorialController.incrementView);

module.exports = router;
