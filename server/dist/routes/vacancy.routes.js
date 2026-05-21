"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const vacancy_controller_1 = require("../controllers/vacancy.controller");
const router = (0, express_1.Router)();
router.use(auth_middleware_1.authenticate);
// Seeker + Employer: read
router.get('/', vacancy_controller_1.listVacancies);
router.get('/map', vacancy_controller_1.getMapVacancies);
router.get('/employer/mine', (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.getEmployerVacancies);
router.get('/:id', vacancy_controller_1.getVacancy);
// Employer only: manage
router.post('/', (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.createVacancy);
router.post('/ai-description', (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.aiVacancyDescription);
router.patch('/:id', (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.updateVacancy);
router.delete('/:id', (0, auth_middleware_1.requireRole)('EMPLOYER'), vacancy_controller_1.deleteVacancy);
// Seeker only: apply
router.post('/:id/apply', (0, auth_middleware_1.requireRole)('SEEKER'), vacancy_controller_1.applyToVacancy);
exports.default = router;
