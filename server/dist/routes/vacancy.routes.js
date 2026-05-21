"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const validate_middleware_1 = require("../middleware/validate.middleware");
const schemas_1 = require("../validation/schemas");
const vacancy_controller_1 = require("../controllers/vacancy.controller");
const router = (0, express_1.Router)();
// Static paths MUST come before /:id
router.get('/map', auth_middleware_1.authenticate, vacancy_controller_1.getMapVacancies);
router.get('/employer/mine', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.getEmployerVacancies);
router.post('/ai-description', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.aiGenerateDescription);
// Collection
router.get('/', auth_middleware_1.authenticate, vacancy_controller_1.listVacancies);
router.post('/', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('EMPLOYER'), (0, validate_middleware_1.validate)(schemas_1.createVacancySchema), vacancy_controller_1.createVacancy);
// Item
router.get('/:id', auth_middleware_1.authenticate, vacancy_controller_1.getVacancy);
router.patch('/:id', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.updateVacancy);
router.delete('/:id', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.deleteVacancy);
router.post('/:id/apply', auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('SEEKER'), vacancy_controller_1.applyToVacancy);
exports.default = router;
