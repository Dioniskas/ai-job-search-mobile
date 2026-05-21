"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const admin_controller_1 = require("../controllers/admin.controller");
const router = (0, express_1.Router)();
// Public — only when no admin exists
router.post('/create-admin', admin_controller_1.createAdmin);
// Protected — ADMIN only
router.use(auth_middleware_1.authenticate, (0, auth_middleware_1.requireRole)('ADMIN'));
router.get('/dashboard', admin_controller_1.getDashboard);
router.get('/users', admin_controller_1.getUsers);
router.get('/users/:id', admin_controller_1.getUserDetail);
router.post('/users/:id/block', admin_controller_1.blockUser);
router.post('/users/:id/unblock', admin_controller_1.unblockUser);
router.get('/vacancies', admin_controller_1.getVacancies);
router.post('/vacancies/:id/moderate', admin_controller_1.moderateVacancy);
router.post('/vacancies/:id/reject', admin_controller_1.rejectVacancy);
router.get('/employers', admin_controller_1.getEmployers);
router.post('/employers/:id/verify', admin_controller_1.verifyEmployer);
router.get('/reports', admin_controller_1.getReports);
router.post('/reports/:id/resolve', admin_controller_1.resolveReport);
router.get('/payments', admin_controller_1.getPayments);
exports.default = router;
