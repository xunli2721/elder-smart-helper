const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');

router.post('/bind', userController.bindFamily);
router.get('/family', userController.getFamily);
router.delete('/family/:id', userController.unbindFamily);
router.put('/settings', userController.updateSettings);
router.post('/online-status', userController.getOnlineStatus);

module.exports = router;