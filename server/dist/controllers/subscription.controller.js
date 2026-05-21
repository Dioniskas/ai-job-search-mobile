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
// GET /api/subscriptions
async function getSubscriptions(req, res) {
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
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
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/subscriptions
async function createSubscription(req, res) {
    const { query, city, salaryMin, employmentType } = req.body;
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
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
        (0, response_1.ok)(res, { subscription });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/subscriptions/:id
async function deleteSubscription(req, res) {
    const { id } = req.params;
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
            return;
        }
        const sub = await prisma_1.default.vacancySubscription.findUnique({ where: { id } });
        if (!sub || sub.seekerId !== seeker.id) {
            (0, response_1.fail)(res, 'Subscription not found or access denied');
            return;
        }
        await prisma_1.default.vacancySubscription.delete({ where: { id } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
