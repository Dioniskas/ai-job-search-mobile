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
async function findSeeker(req) {
    return prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
}
// GET /api/saved
async function getSavedVacancies(req, res) {
    try {
        const seeker = await findSeeker(req);
        if (!seeker) {
            (0, response_1.ok)(res, { saved: [] });
            return;
        }
        const saved = await prisma_1.default.savedVacancy.findMany({
            where: { seekerId: seeker.id },
            include: {
                vacancy: {
                    include: { employer: { select: { companyName: true, logoUrl: true } } },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
        (0, response_1.ok)(res, { saved });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/saved/:vacancyId
async function saveVacancy(req, res) {
    const { vacancyId } = req.params;
    try {
        const seeker = await findSeeker(req);
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
            return;
        }
        const record = await prisma_1.default.savedVacancy.upsert({
            where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
            create: { seekerId: seeker.id, vacancyId },
            update: {},
        });
        (0, response_1.ok)(res, { saved: record });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/saved/:vacancyId
async function unsaveVacancy(req, res) {
    const { vacancyId } = req.params;
    try {
        const seeker = await findSeeker(req);
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
            return;
        }
        await prisma_1.default.savedVacancy.deleteMany({ where: { seekerId: seeker.id, vacancyId } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// GET /api/saved/:vacancyId/check
async function checkSavedVacancy(req, res) {
    const { vacancyId } = req.params;
    try {
        const seeker = await findSeeker(req);
        if (!seeker) {
            (0, response_1.ok)(res, { isSaved: false });
            return;
        }
        const record = await prisma_1.default.savedVacancy.findUnique({
            where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
        });
        (0, response_1.ok)(res, { isSaved: !!record });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
