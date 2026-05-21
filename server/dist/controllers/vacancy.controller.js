"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.listVacancies = listVacancies;
exports.getMapVacancies = getMapVacancies;
exports.getEmployerVacancies = getEmployerVacancies;
exports.getVacancy = getVacancy;
exports.createVacancy = createVacancy;
exports.updateVacancy = updateVacancy;
exports.deleteVacancy = deleteVacancy;
exports.aiVacancyDescription = aiVacancyDescription;
exports.applyToVacancy = applyToVacancy;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const groq_service_1 = require("../services/ai/groq.service");
// ── List vacancies (public-ish, requires auth) ─────────────────────────────────
async function listVacancies(req, res) {
    try {
        const { search, city, salaryMin, salaryMax, employmentType, experience } = req.query;
        const where = { isActive: true };
        if (search) {
            where.title = { contains: search, mode: 'insensitive' };
        }
        if (city) {
            where.city = { contains: city, mode: 'insensitive' };
        }
        if (employmentType) {
            where.employmentType = employmentType;
        }
        if (experience) {
            where.experience = experience;
        }
        if (salaryMin || salaryMax) {
            where.salaryMin = {};
            if (salaryMin)
                where.salaryMin.gte = parseInt(salaryMin, 10);
            if (salaryMax)
                where.salaryMin.lte = parseInt(salaryMax, 10);
        }
        const now = new Date();
        const vacancies = await prisma_1.default.vacancy.findMany({
            where,
            include: {
                employer: {
                    select: { companyName: true, logoUrl: true, city: true },
                },
            },
            orderBy: [
                { boostedUntil: 'desc' },
                { createdAt: 'desc' },
            ],
            take: 50,
        });
        // Mark boosted
        const result = vacancies.map((v) => ({
            ...v,
            isBoosted: v.boostedUntil !== null && v.boostedUntil > now,
        }));
        (0, response_1.ok)(res, { vacancies: result });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Map vacancies (with lat/lng only) ──────────────────────────────────────────
async function getMapVacancies(req, res) {
    try {
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: {
                isActive: true,
                lat: { not: null },
                lng: { not: null },
            },
            select: {
                id: true,
                title: true,
                salaryMin: true,
                salaryMax: true,
                lat: true,
                lng: true,
                city: true,
                employer: { select: { companyName: true, logoUrl: true } },
            },
            orderBy: { createdAt: 'desc' },
            take: 100,
        });
        (0, response_1.ok)(res, { vacancies });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Get employer's own vacancies ────────────────────────────────────────────────
async function getEmployerVacancies(req, res) {
    try {
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.ok)(res, { vacancies: [] });
            return;
        }
        const now = new Date();
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: { employerId: employer.id },
            orderBy: { createdAt: 'desc' },
        });
        const result = vacancies.map((v) => ({
            ...v,
            isBoosted: v.boostedUntil !== null && v.boostedUntil > now,
        }));
        (0, response_1.ok)(res, { vacancies: result });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Get single vacancy ─────────────────────────────────────────────────────────
async function getVacancy(req, res) {
    try {
        const { id } = req.params;
        const vacancy = await prisma_1.default.vacancy.findUnique({
            where: { id },
            include: {
                employer: {
                    select: {
                        id: true,
                        companyName: true,
                        logoUrl: true,
                        city: true,
                        website: true,
                        description: true,
                    },
                },
            },
        });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        // Increment view count
        await prisma_1.default.vacancy.update({
            where: { id },
            data: { viewCount: { increment: 1 } },
        }).catch(() => null);
        // Similar vacancies (same city or employer, different id)
        const similar = await prisma_1.default.vacancy.findMany({
            where: {
                id: { not: id },
                isActive: true,
                OR: [
                    { city: vacancy.city ?? undefined },
                    { employerId: vacancy.employerId },
                ],
            },
            include: {
                employer: { select: { companyName: true, logoUrl: true } },
            },
            take: 5,
            orderBy: { createdAt: 'desc' },
        });
        (0, response_1.ok)(res, { vacancy, similar });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Create vacancy ─────────────────────────────────────────────────────────────
async function createVacancy(req, res) {
    try {
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.fail)(res, 'Сначала создайте профиль компании', 400);
            return;
        }
        const { title, description, salaryMin, salaryMax, city, lat, lng, employmentType, experience, } = req.body;
        if (!title || !description) {
            (0, response_1.fail)(res, 'title и description обязательны');
            return;
        }
        const vacancy = await prisma_1.default.vacancy.create({
            data: {
                employerId: employer.id,
                title,
                description,
                salaryMin: salaryMin ?? null,
                salaryMax: salaryMax ?? null,
                city: city ?? null,
                lat: lat ?? null,
                lng: lng ?? null,
                employmentType: employmentType ?? null,
                experience: experience ?? null,
            },
            include: {
                employer: { select: { companyName: true, logoUrl: true } },
            },
        });
        (0, response_1.ok)(res, { vacancy }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Update vacancy ─────────────────────────────────────────────────────────────
async function updateVacancy(req, res) {
    try {
        const { id } = req.params;
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.fail)(res, 'Профиль работодателя не найден', 404);
            return;
        }
        const existing = await prisma_1.default.vacancy.findFirst({
            where: { id, employerId: employer.id },
        });
        if (!existing) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        const { title, description, salaryMin, salaryMax, city, lat, lng, employmentType, experience, isActive, } = req.body;
        const vacancy = await prisma_1.default.vacancy.update({
            where: { id },
            data: {
                ...(title !== undefined && { title }),
                ...(description !== undefined && { description }),
                ...(salaryMin !== undefined && { salaryMin }),
                ...(salaryMax !== undefined && { salaryMax }),
                ...(city !== undefined && { city }),
                ...(lat !== undefined && { lat }),
                ...(lng !== undefined && { lng }),
                ...(employmentType !== undefined && { employmentType }),
                ...(experience !== undefined && { experience }),
                ...(isActive !== undefined && { isActive }),
            },
        });
        (0, response_1.ok)(res, { vacancy });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Delete vacancy ─────────────────────────────────────────────────────────────
async function deleteVacancy(req, res) {
    try {
        const { id } = req.params;
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const existing = await prisma_1.default.vacancy.findFirst({
            where: { id, employerId: employer.id },
        });
        if (!existing) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        await prisma_1.default.vacancy.delete({ where: { id } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── AI vacancy description ─────────────────────────────────────────────────────
async function aiVacancyDescription(req, res) {
    try {
        const { title, requirements, conditions } = req.body;
        if (!title) {
            (0, response_1.fail)(res, 'title обязателен');
            return;
        }
        const description = await (0, groq_service_1.generateVacancyDescription)({ title, requirements, conditions });
        (0, response_1.ok)(res, { description });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка AI: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Apply to vacancy ───────────────────────────────────────────────────────────
async function applyToVacancy(req, res) {
    try {
        const { id: vacancyId } = req.params;
        const { resumeId, coverLetter } = req.body;
        if (!resumeId) {
            (0, response_1.fail)(res, 'resumeId обязателен');
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.fail)(res, 'Создайте профиль соискателя', 400);
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findUnique({
            where: { id: vacancyId },
            include: { employer: { select: { id: true, userId: true } } },
        });
        if (!vacancy || !vacancy.isActive) {
            (0, response_1.fail)(res, 'Вакансия не найдена или закрыта', 404);
            return;
        }
        const resume = await prisma_1.default.resume.findFirst({
            where: { id: resumeId, seekerId: seeker.id },
        });
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено', 404);
            return;
        }
        // Check if already applied
        const existing = await prisma_1.default.application.findFirst({
            where: { resumeId, vacancyId },
        });
        if (existing) {
            (0, response_1.fail)(res, 'Вы уже откликались на эту вакансию', 409);
            return;
        }
        const application = await prisma_1.default.application.create({
            data: {
                resumeId,
                vacancyId,
                seekerId: seeker.id,
                employerId: vacancy.employer.id,
                coverLetter: coverLetter ?? null,
            },
        });
        // Notify employer
        await prisma_1.default.notification.create({
            data: {
                userId: vacancy.employer.userId,
                type: 'NEW_APPLICATION',
                text: `Новый отклик на вакансию "${vacancy.title}"`,
                link: `/applications/${application.id}`,
            },
        }).catch(() => null);
        (0, response_1.ok)(res, { application }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
