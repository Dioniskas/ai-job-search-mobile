"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const auth_controller_1 = require("../controllers/auth.controller");
const google_auth_controller_1 = require("../controllers/google-auth.controller");
const auth_middleware_1 = require("../middleware/auth.middleware");
const validate_middleware_1 = require("../middleware/validate.middleware");
const schemas_1 = require("../validation/schemas");
const loginLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60 * 1000,
    max: 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Слишком много попыток входа. Попробуйте через минуту.' },
});
const registerLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60 * 60 * 1000,
    max: 3,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Слишком много регистраций с вашего IP. Попробуйте через час.' },
});
const router = (0, express_1.Router)();
router.post('/register', registerLimiter, (0, validate_middleware_1.validate)(schemas_1.registerSchema), auth_controller_1.register);
router.post('/login', loginLimiter, (0, validate_middleware_1.validate)(schemas_1.loginSchema), auth_controller_1.login);
router.post('/refresh', (0, validate_middleware_1.validate)(schemas_1.refreshSchema), auth_controller_1.refresh);
router.post('/logout', auth_middleware_1.authenticate, auth_controller_1.logout);
router.get('/me', auth_middleware_1.authenticate, auth_controller_1.me);
router.post('/forgot-password', loginLimiter, auth_controller_1.forgotPassword);
router.post('/reset-password', auth_controller_1.resetPassword);
router.post('/google/mobile', google_auth_controller_1.googleMobileAuth);
router.post('/google/complete', google_auth_controller_1.googleCompleteAuth);
exports.default = router;
