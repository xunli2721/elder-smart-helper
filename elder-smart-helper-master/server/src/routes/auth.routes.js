const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { verifyToken } = require('../middleware/auth');
const { registerRules, loginRules, changePasswordRules } = require('../middleware/validator');

router.post('/register', registerRules, authController.register);
router.post('/login', loginRules, authController.login);
router.get('/profile', verifyToken, authController.getProfile);
router.put('/password', verifyToken, changePasswordRules, authController.changePassword);
router.post('/refresh', verifyToken, authController.refreshToken);

module.exports = router;
