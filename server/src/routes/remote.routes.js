const express = require('express');
const router = express.Router();
const remoteController = require('../controllers/remote.controller');

router.post('/request', remoteController.requestSession);
router.get('/sessions', remoteController.getSessions);
router.put('/sessions/:id/status', remoteController.updateStatus);

module.exports = router;
