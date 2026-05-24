const express = require('express');
const router = express.Router();
const tutorialController = require('../controllers/tutorial.controller');
const { verifyToken } = require('../middleware/auth');

router.get('/', tutorialController.getAll);
router.get('/:id', tutorialController.getById);
router.post('/', verifyToken, tutorialController.create);
router.put('/:id', verifyToken, tutorialController.update);
router.delete('/:id', verifyToken, tutorialController.remove);

module.exports = router;
