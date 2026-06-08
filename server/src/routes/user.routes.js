const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');

/**
 * @swagger
 * /api/users/bind:
 *   post:
 *     summary: 绑定家人
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone]
 *             properties:
 *               phone:
 *                 type: string
 *                 example: '13800000002'
 *                 description: 家人手机号
 *               relationship:
 *                 type: string
 *                 enum: [child, spouse, relative, friend, caregiver]
 *                 default: child
 *                 description: 关系类型
 *     responses:
 *       200:
 *         description: 绑定成功
 *       400:
 *         description: 已绑定、不能绑定自己或参数错误
 *       404:
 *         description: 未找到该用户
 */
router.post('/bind', userController.bindFamily);

/**
 * @swagger
 * /api/users/family:
 *   get:
 *     summary: 获取已绑定的家人列表
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取家人列表
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       name:
 *                         type: string
 *                       phone:
 *                         type: string
 *                       user_type:
 *                         type: string
 *                       relationship:
 *                         type: string
 */
router.get('/family', userController.getFamily);

/**
 * @swagger
 * /api/users/family/{id}:
 *   delete:
 *     summary: 解除家人绑定
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 绑定关系 ID
 *     responses:
 *       200:
 *         description: 解除绑定成功
 *       404:
 *         description: 绑定关系不存在
 */
router.delete('/family/:id', userController.unbindFamily);

/**
 * @swagger
 * /api/users/settings:
 *   put:
 *     summary: 更新用户设置
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: '新名字'
 *               font_size:
 *                 type: string
 *                 enum: [small, medium, large, xlarge]
 *                 example: large
 *     responses:
 *       200:
 *         description: 更新成功
 *       400:
 *         description: 没有要更新的内容
 */
router.put('/settings', userController.updateSettings);

/**
 * @swagger
 * /api/users/online-status:
 *   post:
 *     summary: 查询用户在线状态
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [userIds]
 *             properties:
 *               userIds:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [1, 2, 3]
 *                 description: 用户 ID 列表
 *     responses:
 *       200:
 *         description: 成功获取在线状态
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   example:
 *                     '1': true
 *                     '2': false
 */
router.post('/online-status', userController.getOnlineStatus);

module.exports = router;
