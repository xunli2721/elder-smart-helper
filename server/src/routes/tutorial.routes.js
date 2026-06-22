const express = require('express');
const router = express.Router();
const tutorialController = require('../controllers/tutorial.controller');
const { verifyToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');

/**
 * @swagger
 * /api/tutorials:
 *   get:
 *     summary: 获取教程列表
 *     tags: [Tutorials]
 *     parameters:
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *           enum: [basic, communication, payment, entertainment, utility]
 *         description: 按分类筛选
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
 *         description: 成功获取教程列表
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
 *                     $ref: '#/components/schemas/Tutorial'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     pageSize:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 */
router.get('/', tutorialController.getAll);

/**
 * @swagger
 * /api/tutorials/{id}:
 *   get:
 *     summary: 获取教程详情
 *     tags: [Tutorials]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: 教程 ID
 *     responses:
 *       200:
 *         description: 成功获取教程详情
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Tutorial'
 *       404:
 *         description: 教程不存在
 */
router.get('/:id', tutorialController.getById);

/**
 * @swagger
 * /api/tutorials:
 *   post:
 *     summary: 创建教程（仅管理员）
 *     tags: [Tutorials]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title, category, steps]
 *             properties:
 *               title:
 *                 type: string
 *                 example: '如何拨打电话'
 *               description:
 *                 type: string
 *                 example: '学习使用手机拨打电话'
 *               category:
 *                 type: string
 *                 enum: [basic, communication, payment, entertainment, utility]
 *               difficulty_level:
 *                 type: string
 *                 enum: [beginner, intermediate, advanced]
 *                 default: beginner
 *               image_url:
 *                 type: string
 *               steps:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     step:
 *                       type: integer
 *                     title:
 *                       type: string
 *                     description:
 *                       type: string
 *     responses:
 *       200:
 *         description: 创建成功
 *       400:
 *         description: 缺少必填字段
 *       401:
 *         description: 未登录
 *       403:
 *         description: 权限不足（非管理员）
 */
router.post('/', verifyToken, requireRole('admin'), tutorialController.create);

/**
 * @swagger
 * /api/tutorials/{id}:
 *   put:
 *     summary: 更新教程（仅管理员）
 *     tags: [Tutorials]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               category:
 *                 type: string
 *               difficulty_level:
 *                 type: string
 *               image_url:
 *                 type: string
 *               steps:
 *                 type: array
 *     responses:
 *       200:
 *         description: 更新成功
 *       404:
 *         description: 教程不存在
 */
router.put('/:id', verifyToken, requireRole('admin'), tutorialController.update);

/**
 * @swagger
 * /api/tutorials/{id}:
 *   delete:
 *     summary: 删除教程（仅管理员，软删除）
 *     tags: [Tutorials]
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
 *         description: 删除成功
 *       404:
 *         description: 教程不存在
 */
router.delete('/:id', verifyToken, requireRole('admin'), tutorialController.remove);

module.exports = router;
