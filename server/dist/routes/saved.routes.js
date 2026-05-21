"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const saved_controller_1 = require("../controllers/saved.controller");
const router = (0, express_1.Router)();
router.use(auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('SEEKER'));
// Static paths before /:vacancyId
router.get('/', saved_controller_1.getSavedVacancies);
router.get('/:vacancyId/check', saved_controller_1.checkSavedVacancy);
router.post('/:vacancyId', saved_controller_1.saveVacancy);
router.delete('/:vacancyId', saved_controller_1.unsaveVacancy);
exports.default = router;
