"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_middleware_1 = require("../middleware/auth.middleware");
const payment_controller_1 = require("../controllers/payment.controller");
const router = (0, express_1.Router)();
// Public callbacks from payment systems (no JWT)
router.post('/payme/callback', payment_controller_1.paymeCallback);
router.post('/click/callback', payment_controller_1.clickCallback);
// Authenticated routes
router.use(auth_middleware_1.authenticate);
router.post('/payme/create', payment_controller_1.createPaymePayment);
router.post('/click/create', payment_controller_1.createClickPayment);
router.post('/test/complete', payment_controller_1.completeTestPayment);
router.get('/history', payment_controller_1.getPaymentHistory);
exports.default = router;
