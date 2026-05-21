"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getNotifications = getNotifications;
exports.markNotificationsRead = markNotificationsRead;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
// GET /api/notifications
async function getNotifications(req, res) {
    try {
        const { userId } = req.user;
        const [notifications, unreadCount] = await Promise.all([
            prisma_1.default.notification.findMany({
                where: { userId },
                orderBy: { createdAt: 'desc' },
                take: 50,
            }),
            prisma_1.default.notification.count({
                where: { userId, isRead: false },
            }),
        ]);
        (0, response_1.ok)(res, { notifications, unreadCount });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// PATCH /api/notifications/read
async function markNotificationsRead(req, res) {
    try {
        const { userId } = req.user;
        await prisma_1.default.notification.updateMany({
            where: { userId, isRead: false },
            data: { isRead: true },
        });
        (0, response_1.ok)(res, { marked: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
