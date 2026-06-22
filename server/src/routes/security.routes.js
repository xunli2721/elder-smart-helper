const express = require('express');
const router = express.Router();
const securityController = require('../controllers/security.controller');

/**
 * @swagger
 * /api/security/check-fraud:
 *   post:
 *     summary: 检测诈骗风险
 *     tags: [Security]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [text]
 *             properties:
 *               text:
 *                 type: string
 *                 example: '恭喜你中奖了，请转账1000元手续费到安全账户'
 *                 description: 待检测文本
 *     responses:
 *       200:
 *         description: 检测结果
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     hasRisk:
 *                       type: boolean
 *                     risks:
 *                       type: array
 *                     matchedKeywords:
 *                       type: array
 *                     hasSuspiciousLinks:
 *                       type: boolean
 */
router.post('/check-fraud', securityController.checkFraud);

/**
 * @swagger
 * /api/security/check-payment:
 *   post:
 *     summary: 检测支付风险
 *     tags: [Security]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [amount]
 *             properties:
 *               amount:
 *                 type: number
 *                 example: 5000
 *                 description: 支付金额（元）
 *     responses:
 *       200:
 *         description: 检测结果
 */
router.post('/check-payment', securityController.checkPayment);

/**
 * @swagger
 * /api/security/events:
 *   get:
 *     summary: 获取安全事件列表
 *     tags: [Security]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: pageSize
 *         schema:
 *           type: integer
 *       - in: query
 *         name: severity
 *         schema:
 *           type: string
 *           enum: [low, medium, high, critical]
 *     responses:
 *       200:
 *         description: 安全事件列表
 */
router.get('/events', securityController.getEvents);

/**
 * @swagger
 * /api/security/events/{id}/resolve:
 *   put:
 *     summary: 标记安全事件为已解决
 *     tags: [Security]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: 操作成功
 *       404:
 *         description: 事件不存在
 */
router.put('/events/:id/resolve', securityController.resolveEvent);

/**
 * @swagger
 * /api/security/stats:
 *   get:
 *     summary: 获取安全概览统计
 *     tags: [Security]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 安全统计
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     total_events:
 *                       type: integer
 *                     unresolved:
 *                       type: integer
 *                     critical_unresolved:
 *                       type: integer
 *                     high_unresolved:
 *                       type: integer
 *                     last_7_days:
 *                       type: integer
 */
router.get('/stats', securityController.getStats);

module.exports = router;
