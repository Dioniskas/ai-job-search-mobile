"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const report_controller_1 = require("../controllers/report.controller");
const router = (0, express_1.Router)();
router.post('/', auth_middleware_1.authenticate, report_controller_1.createReport);
exports.default = router;
