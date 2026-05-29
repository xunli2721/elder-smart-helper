const express = require('express');
const router = express.Router();
const tutorialController = require('../controllers/tutorial.controller');
const { verifyToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');

// 查看教程：所有人可访问
router.get('/', tutorialController.getAll);
router.get('/:id', tutorialController.getById);

// 创建/更新/删除教程：仅 admin 角色
router.post('/', verifyToken, requireRole('admin'), tutorialController.create);
router.put('/:id', verifyToken, requireRole('admin'), tutorialController.update);
router.delete('/:id', verifyToken, requireRole('admin'), tutorialController.remove);

module.exports = router;