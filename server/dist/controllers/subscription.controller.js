"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSubscriptions = getSubscriptions;
exports.createSubscription = createSubscription;
exports.deleteSubscription = deleteSubscription;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function getSeeker(userId) {
    return prisma_1.default.seekerProfile.findUnique({ where: { userId } });
}
// GET /api/subscriptions
async function getSubscriptions(req, res) {
    try {
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.ok)(res, { subscriptions: [] });
            return;
        }
        const subscriptions = await prisma_1.default.vacancySubscription.findMany({
            where: { seekerId: seeker.id },
            orderBy: { createdAt: 'desc' },
        });
        (0, response_1.ok)(res, { subscriptions });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/subscriptions
async function createSubscription(req, res) {
    try {
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.fail)(res, 'Создайте профиль соискателя', 400);
            return;
        }
        const { query, city, salaryMin, employmentType } = req.body;
        if (!query && !city && !employmentType) {
            (0, response_1.fail)(res, 'Укажите хотя бы один критерий поиска');
            return;
        }
        const subscription = await prisma_1.default.vacancySubscription.create({
            data: {
                seekerId: seeker.id,
                query: query ?? null,
                city: city ?? null,
                salaryMin: salaryMin ?? null,
                employmentType: employmentType ?? null,
            },
        });
        (0, response_1.ok)(res, { subscription }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/subscriptions/:id
async function deleteSubscription(req, res) {
    try {
        const { id } = req.params;
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const existing = await prisma_1.default.vacancySubscription.findFirst({
            where: { id, seekerId: seeker.id },
        });
        if (!existing) {
            (0, response_1.fail)(res, 'Подписка не найдена', 404);
            return;
        }
        await prisma_1.default.vacancySubscription.delete({ where: { id } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
