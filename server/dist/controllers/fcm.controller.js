"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.saveFcmToken = saveFcmToken;
exports.deleteFcmToken = deleteFcmToken;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
// POST /api/users/fcm-token
async function saveFcmToken(req, res) {
    const { token } = req.body;
    if (!token) {
        (0, response_1.fail)(res, 'token is required');
        return;
    }
    try {
        await prisma_1.default.user.update({
            where: { id: req.user.userId },
            data: { fcmToken: token },
        });
        (0, response_1.ok)(res, { success: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/users/fcm-token  — call on logout
async function deleteFcmToken(req, res) {
    try {
        await prisma_1.default.user.update({
            where: { id: req.user.userId },
            data: { fcmToken: null },
        });
        (0, response_1.ok)(res, { success: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
