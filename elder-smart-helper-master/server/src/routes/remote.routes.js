const express = require('express');
const router = express.Router();
const remoteController = require('../controllers/remote.controller');
const { requestSessionRules, updateStatusRules } = require('../middleware/validator');

router.post('/request', requestSessionRules, remoteController.requestSession);
router.get('/sessions', remoteController.getSessions);
router.put('/sessions/:id/status', updateStatusRules, remoteController.updateStatus);

module.exports = router;
