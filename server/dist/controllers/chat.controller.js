"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getConversations = getConversations;
exports.getMessages = getMessages;
exports.sendMessage = sendMessage;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const io_1 = require("../lib/io");
async function getConversations(req, res) {
    try {
        const { userId, role } = req.user;
        if (role === 'SEEKER') {
            const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId } });
            if (!seeker) {
                (0, response_1.fail)(res, 'Профиль соискателя не найден', 404);
                return;
            }
            const applications = await prisma_1.default.application.findMany({
                where: { seekerId: seeker.id },
                include: {
                    vacancy: { select: { title: true } },
                    employer: { select: { companyName: true, logoUrl: true } },
                    messages: { orderBy: { createdAt: 'desc' }, take: 1 },
                },
                orderBy: { createdAt: 'desc' },
            });
            const conversations = await Promise.all(applications.map(async (app) => {
                const unreadCount = await prisma_1.default.message.count({
                    where: { applicationId: app.id, receiverId: userId, isRead: false },
                });
                return {
                    applicationId: app.id,
                    partyName: app.employer.companyName,
                    partyAvatar: app.employer.logoUrl,
                    vacancyTitle: app.vacancy.title,
                    lastMessage: app.messages[0] ?? null,
                    unreadCount,
                    status: app.status,
                };
            }));
            (0, response_1.ok)(res, { conversations });
        }
        else {
            const employer = await prisma_1.default.employer.findUnique({ where: { userId } });
            if (!employer) {
                (0, response_1.fail)(res, 'Профиль работодателя не найден', 404);
                return;
            }
            const applications = await prisma_1.default.application.findMany({
                where: { employerId: employer.id },
                include: {
                    seeker: { select: { firstName: true, lastName: true, photoUrl: true } },
                    vacancy: { select: { title: true } },
                    messages: { orderBy: { createdAt: 'desc' }, take: 1 },
                },
                orderBy: { createdAt: 'desc' },
            });
            const conversations = await Promise.all(applications.map(async (app) => {
                const unreadCount = await prisma_1.default.message.count({
                    where: { applicationId: app.id, receiverId: userId, isRead: false },
                });
                return {
                    applicationId: app.id,
                    partyName: `${app.seeker.firstName} ${app.seeker.lastName}`,
                    partyAvatar: app.seeker.photoUrl,
                    vacancyTitle: app.vacancy.title,
                    lastMessage: app.messages[0] ?? null,
                    unreadCount,
                    status: app.status,
                };
            }));
            (0, response_1.ok)(res, { conversations });
        }
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getMessages(req, res) {
    try {
        const { userId } = req.user;
        const { applicationId } = req.params;
        const application = await prisma_1.default.application.findUnique({
            where: { id: applicationId },
            include: {
                seeker: { select: { userId: true } },
                employer: { select: { userId: true } },
            },
        });
        if (!application) {
            (0, response_1.fail)(res, 'Отклик не найден', 404);
            return;
        }
        const isParticipant = application.seeker.userId === userId || application.employer.userId === userId;
        if (!isParticipant) {
            (0, response_1.fail)(res, 'Доступ запрещён', 403);
            return;
        }
        await prisma_1.default.message.updateMany({
            where: { applicationId, receiverId: userId, isRead: false },
            data: { isRead: true },
        });
        const messages = await prisma_1.default.message.findMany({
            where: { applicationId },
            orderBy: { createdAt: 'asc' },
            select: {
                id: true,
                senderId: true,
                receiverId: true,
                applicationId: true,
                text: true,
                isRead: true,
                createdAt: true,
            },
        });
        (0, response_1.ok)(res, { messages });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function sendMessage(req, res) {
    try {
        const { userId } = req.user;
        const { applicationId } = req.params;
        const { text } = req.body;
        if (!text?.trim()) {
            (0, response_1.fail)(res, 'Текст сообщения обязателен');
            return;
        }
        const application = await prisma_1.default.application.findUnique({
            where: { id: applicationId },
            include: {
                seeker: { select: { userId: true } },
                employer: { select: { userId: true } },
            },
        });
        if (!application) {
            (0, response_1.fail)(res, 'Отклик не найден', 404);
            return;
        }
        const isSeeker = application.seeker.userId === userId;
        const isEmployer = application.employer.userId === userId;
        if (!isSeeker && !isEmployer) {
            (0, response_1.fail)(res, 'Доступ запрещён', 403);
            return;
        }
        const receiverId = isSeeker ? application.employer.userId : application.seeker.userId;
        const message = await prisma_1.default.message.create({
            data: { senderId: userId, receiverId, applicationId, text: text.trim() },
            select: {
                id: true,
                senderId: true,
                receiverId: true,
                applicationId: true,
                text: true,
                isRead: true,
                createdAt: true,
            },
        });
        try {
            (0, io_1.getIo)().to(`app_${applicationId}`).emit('new_message', message);
        }
        catch {
            // Socket not yet initialized or no active room; REST response is sufficient
        }
        (0, response_1.ok)(res, { message }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
