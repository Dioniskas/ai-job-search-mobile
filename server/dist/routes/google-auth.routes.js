"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const google_auth_controller_1 = require("../controllers/google-auth.controller");
const router = (0, express_1.Router)();
router.post('/mobile', google_auth_controller_1.googleMobileAuth);
exports.default = router;
