"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.boostResume = boostResume;
exports.boostVacancy = boostVacancy;
exports.getBoostStatus = getBoostStatus;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const VALID_DAYS = [7, 30, 90];
function boostUntil(days) {
    const d = new Date();
    d.setDate(d.getDate() + days);
    return d;
}
async function boostResume(req, res) {
    try {
        const { userId } = req.user;
        const { days } = req.body;
        if (!VALID_DAYS.includes(days)) {
            (0, response_1.fail)(res, `days должен быть одним из: ${VALID_DAYS.join(', ')}`);
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль соискателя не найден', 404);
            return;
        }
        const until = boostUntil(days);
        const updated = await prisma_1.default.seekerProfile.update({
            where: { id: seeker.id },
            data: { boostedUntil: until },
            select: { boostedUntil: true },
        });
        (0, response_1.ok)(res, {
            boostedUntil: updated.boostedUntil,
            days,
            message: `Резюме поднято в поиске на ${days} дней`,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function boostVacancy(req, res) {
    try {
        const { userId } = req.user;
        const { vacancyId, days } = req.body;
        if (!vacancyId) {
            (0, response_1.fail)(res, 'vacancyId обязателен');
            return;
        }
        if (!VALID_DAYS.includes(days)) {
            (0, response_1.fail)(res, `days должен быть одним из: ${VALID_DAYS.join(', ')}`);
            return;
        }
        const employer = await prisma_1.default.employer.findUnique({ where: { userId } });
        if (!employer) {
            (0, response_1.fail)(res, 'Профиль работодателя не найден', 404);
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        if (vacancy.employerId !== employer.id) {
            (0, response_1.fail)(res, 'Нет доступа к этой вакансии', 403);
            return;
        }
        const until = boostUntil(days);
        const updated = await prisma_1.default.vacancy.update({
            where: { id: vacancyId },
            data: { boostedUntil: until },
            select: { id: true, title: true, boostedUntil: true },
        });
        (0, response_1.ok)(res, {
            vacancy: updated,
            days,
            message: `Вакансия "${updated.title}" продвинута на ${days} дней`,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getBoostStatus(req, res) {
    try {
        const { userId, role } = req.user;
        const now = new Date();
        if (role === 'SEEKER') {
            const seeker = await prisma_1.default.seekerProfile.findUnique({
                where: { userId },
                select: { boostedUntil: true },
            });
            const boostedUntil = seeker?.boostedUntil ?? null;
            (0, response_1.ok)(res, {
                isBoosted: boostedUntil !== null && boostedUntil > now,
                boostedUntil,
            });
        }
        else {
            const employer = await prisma_1.default.employer.findUnique({ where: { userId } });
            if (!employer) {
                (0, response_1.fail)(res, 'Профиль не найден', 404);
                return;
            }
            const vacancies = await prisma_1.default.vacancy.findMany({
                where: { employerId: employer.id, isActive: true },
                select: { id: true, title: true, boostedUntil: true },
                orderBy: { createdAt: 'desc' },
            });
            (0, response_1.ok)(res, {
                vacancies: vacancies.map((v) => ({
                    ...v,
                    isBoosted: v.boostedUntil !== null && v.boostedUntil > now,
                })),
            });
        }
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
