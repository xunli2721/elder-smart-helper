const express = require('express');
const router = express.Router();
const remoteController = require('../controllers/remote.controller');

/**
 * @swagger
 * /api/remote/request:
 *   post:
 *     summary: 发起远程协助请求
 *     tags: [Remote Assistance]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [assistant_user_id]
 *             properties:
 *               assistant_user_id:
 *                 type: integer
 *                 example: 2
 *                 description: 协助者用户 ID
 *               request_description:
 *                 type: string
 *                 example: '需要帮忙设置WiFi'
 *                 description: 请求描述
 *     responses:
 *       200:
 *         description: 请求创建成功
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
 *                   properties:
 *                     session_id:
 *                       type: integer
 *                       example: 1
 *       400:
 *         description: 缺少协助者或无绑定关系
 *       401:
 *         description: 未登录
 */
router.post('/request', remoteController.requestSession);

/**
 * @swagger
 * /api/remote/sessions:
 *   get:
 *     summary: 获取远程协助会话列表
 *     tags: [Remote Assistance]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: 页码
 *       - in: query
 *         name: pageSize
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *         description: 每页数量
 *     responses:
 *       200:
 *         description: 成功获取会话列表
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
 *                     $ref: '#/components/schemas/RemoteSession'
 *       401:
 *         description: 未登录
 */
router.get('/sessions', remoteController.getSessions);

/**
 * @swagger
 * /api/remote/sessions/{id}/status:
 *   put:
 *     summary: 更新会话状态
 *     tags: [Remote Assistance]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 会话 ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [active, completed, cancelled]
 *                 description: 新状态
 *     responses:
 *       200:
 *         description: 状态更新成功
 *       400:
 *         description: 无效的状态
 *       404:
 *         description: 会话不存在
 */
router.put('/sessions/:id/status', remoteController.updateStatus);

module.exports = router;
