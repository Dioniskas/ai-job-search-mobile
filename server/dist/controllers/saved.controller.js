"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSavedVacancies = getSavedVacancies;
exports.saveVacancy = saveVacancy;
exports.unsaveVacancy = unsaveVacancy;
exports.checkSavedVacancy = checkSavedVacancy;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function getSeeker(userId) {
    return prisma_1.default.seekerProfile.findUnique({ where: { userId } });
}
// GET /api/saved
async function getSavedVacancies(req, res) {
    try {
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.ok)(res, { saved: [] });
            return;
        }
        const saved = await prisma_1.default.savedVacancy.findMany({
            where: { seekerId: seeker.id },
            include: {
                vacancy: {
                    include: {
                        employer: { select: { companyName: true, logoUrl: true, city: true } },
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
        (0, response_1.ok)(res, { saved: saved.map((s) => s.vacancy) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/saved/:vacancyId
async function saveVacancy(req, res) {
    try {
        const { vacancyId } = req.params;
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.fail)(res, 'Создайте профиль соискателя', 400);
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        await prisma_1.default.savedVacancy.upsert({
            where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
            create: { seekerId: seeker.id, vacancyId },
            update: {},
        });
        (0, response_1.ok)(res, { saved: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/saved/:vacancyId
async function unsaveVacancy(req, res) {
    try {
        const { vacancyId } = req.params;
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        await prisma_1.default.savedVacancy.deleteMany({
            where: { seekerId: seeker.id, vacancyId },
        });
        (0, response_1.ok)(res, { saved: false });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// GET /api/saved/:vacancyId/check
async function checkSavedVacancy(req, res) {
    try {
        const { vacancyId } = req.params;
        const seeker = await getSeeker(req.user.userId);
        if (!seeker) {
            (0, response_1.ok)(res, { isSaved: false });
            return;
        }
        const record = await prisma_1.default.savedVacancy.findFirst({
            where: { seekerId: seeker.id, vacancyId },
        });
        (0, response_1.ok)(res, { isSaved: record !== null });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
