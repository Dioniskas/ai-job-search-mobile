"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getConversations = getConversations;
exports.getMessages = getMessages;
exports.sendMessage = sendMessage;
const response_1 = require("../utils/response");
const fcm_service_1 = require("../services/fcm.service");
const prisma_1 = __importDefault(require("../lib/prisma"));
// GET /api/chat/conversations
async function getConversations(req, res) {
    try {
        const userId = req.user.userId;
        // Find all applications where this user is seeker or employer
        const user = await prisma_1.default.user.findUnique({
            where: { id: userId },
            include: {
                seekerProfile: { select: { id: true, applications: { select: { id: true } } } },
                employerProfile: { select: { id: true, applications: { select: { id: true } } } },
            },
        });
        if (!user) {
            (0, response_1.fail)(res, 'User not found');
            return;
        }
        const appIds = user.role === 'SEEKER'
            ? (user.seekerProfile?.applications ?? []).map(a => a.id)
            : (user.employerProfile?.applications ?? []).map(a => a.id);
        if (appIds.length === 0) {
            (0, response_1.ok)(res, { conversations: [] });
            return;
        }
        // Get last message per application
        const conversations = await Promise.all(appIds.map(async (applicationId) => {
            const [lastMessage, unreadCount, application] = await Promise.all([
                prisma_1.default.message.findFirst({
                    where: { applicationId },
                    orderBy: { createdAt: 'desc' },
                }),
                prisma_1.default.message.count({
                    where: { applicationId, receiverId: userId, isRead: false },
                }),
                prisma_1.default.application.findUnique({
                    where: { id: applicationId },
                    include: {
                        vacancy: { select: { id: true, title: true } },
                        resume: {
                            include: {
                                seeker: { select: { firstName: true, lastName: true, photoUrl: true } },
                            },
                        },
                        employer: { select: { companyName: true, logoUrl: true } },
                    },
                }),
            ]);
            if (!application || !lastMessage)
                return null;
            return { applicationId, application, lastMessage, unreadCount };
        }));
        const result = conversations
            .filter(Boolean)
            .sort((a, b) => new Date(b.lastMessage.createdAt).getTime() - new Date(a.lastMessage.createdAt).getTime());
        (0, response_1.ok)(res, { conversations: result });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// GET /api/chat/:applicationId/messages
async function getMessages(req, res) {
    const { applicationId } = req.params;
    const userId = req.user.userId;
    try {
        const application = await prisma_1.default.application.findUnique({ where: { id: applicationId } });
        if (!application) {
            (0, response_1.fail)(res, 'Application not found');
            return;
        }
        // Verify access: user must be seeker or employer on this application
        const user = await prisma_1.default.user.findUnique({
            where: { id: userId },
            include: {
                seekerProfile: { select: { id: true } },
                employerProfile: { select: { id: true } },
            },
        });
        const hasAccess = (user?.seekerProfile?.id && user.seekerProfile.id === application.seekerId) ||
            (user?.employerProfile?.id && user.employerProfile.id === application.employerId);
        if (!hasAccess) {
            (0, response_1.fail)(res, 'Access denied', 403);
            return;
        }
        const messages = await prisma_1.default.message.findMany({
            where: { applicationId },
            orderBy: { createdAt: 'asc' },
        });
        // Mark received messages as read
        await prisma_1.default.message.updateMany({
            where: { applicationId, receiverId: userId, isRead: false },
            data: { isRead: true },
        });
        (0, response_1.ok)(res, { messages });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/chat/:applicationId/messages
async function sendMessage(req, res) {
    const { applicationId } = req.params;
    const { text } = req.body;
    const senderId = req.user.userId;
    if (!text?.trim()) {
        (0, response_1.fail)(res, 'text is required');
        return;
    }
    try {
        const application = await prisma_1.default.application.findUnique({
            where: { id: applicationId },
            include: {
                vacancy: { select: { title: true } },
                resume: { include: { seeker: { include: { user: { select: { id: true, fcmToken: true } } } } } },
                employer: { include: { user: { select: { id: true, fcmToken: true } } } },
            },
        });
        if (!application) {
            (0, response_1.fail)(res, 'Application not found');
            return;
        }
        // Determine sender/receiver
        const seekerUserId = application.resume.seeker.user.id;
        const employerUserId = application.employer.user.id;
        let receiverId;
        let receiverFcmToken;
        let senderName;
        if (senderId === seekerUserId) {
            receiverId = employerUserId;
            receiverFcmToken = application.employer.user.fcmToken;
            const s = application.resume.seeker;
            senderName = `${s.firstName} ${s.lastName}`.trim();
        }
        else if (senderId === employerUserId) {
            receiverId = seekerUserId;
            receiverFcmToken = application.resume.seeker.user.fcmToken;
            senderName = application.employer.companyName;
        }
        else {
            (0, response_1.fail)(res, 'Access denied', 403);
            return;
        }
        const message = await prisma_1.default.message.create({
            data: { senderId, receiverId, applicationId, text: text.trim() },
        });
        // Push to receiver
        if (receiverFcmToken) {
            await (0, fcm_service_1.sendPush)(receiverFcmToken, `Сообщение от ${senderName}`, text.trim().length > 80 ? text.trim().slice(0, 77) + '...' : text.trim(), { type: 'NEW_MESSAGE', applicationId });
        }
        (0, response_1.ok)(res, { message });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
