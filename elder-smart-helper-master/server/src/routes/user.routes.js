const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const { bindFamilyRules, familyIdRule, updateSettingsRules } = require('../middleware/validator');

router.post('/bind', bindFamilyRules, userController.bindFamily);
router.get('/family', userController.getFamily);
router.delete('/family/:id', familyIdRule, userController.unbindFamily);
router.put('/settings', updateSettingsRules, userController.updateSettings);
router.put('/avatar', userController.updateAvatar);

module.exports = router;
