"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getNotifications = getNotifications;
exports.markAllRead = markAllRead;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
// GET /api/notifications
async function getNotifications(req, res) {
    try {
        const notifications = await prisma_1.default.notification.findMany({
            where: { userId: req.user.userId },
            orderBy: { createdAt: 'desc' },
            take: 30,
        });
        const unreadCount = notifications.filter(n => !n.isRead).length;
        (0, response_1.ok)(res, { notifications, unreadCount });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// PATCH /api/notifications/read  — mark all as read
async function markAllRead(req, res) {
    try {
        await prisma_1.default.notification.updateMany({
            where: { userId: req.user.userId, isRead: false },
            data: { isRead: true },
        });
        (0, response_1.ok)(res, { success: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
