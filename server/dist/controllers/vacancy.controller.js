"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.listVacancies = listVacancies;
exports.getMapVacancies = getMapVacancies;
exports.getEmployerVacancies = getEmployerVacancies;
exports.aiGenerateDescription = aiGenerateDescription;
exports.getVacancy = getVacancy;
exports.createVacancy = createVacancy;
exports.updateVacancy = updateVacancy;
exports.deleteVacancy = deleteVacancy;
exports.applyToVacancy = applyToVacancy;
const response_1 = require("../utils/response");
const groq_service_1 = require("../services/ai/groq.service");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function listVacancies(req, res) {
    try {
        const { search, city, salaryMin, salaryMax, employmentType, experience, page: pageStr, limit: limitStr } = req.query;
        const page = Math.max(1, parseInt(pageStr ?? '1', 10));
        const limit = Math.min(50, Math.max(1, parseInt(limitStr ?? '20', 10)));
        const skip = (page - 1) * limit;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const where = { isActive: true, isModerated: true };
        if (search)
            where['title'] = { contains: search, mode: 'insensitive' };
        if (city)
            where['city'] = { contains: city, mode: 'insensitive' };
        if (salaryMin)
            where['salaryMax'] = { gte: Number(salaryMin) };
        if (salaryMax)
            where['salaryMin'] = { lte: Number(salaryMax) };
        if (employmentType)
            where['employmentType'] = employmentType;
        if (experience)
            where['experience'] = experience;
        const [vacancies, total] = await Promise.all([
            prisma_1.default.vacancy.findMany({
                where,
                include: { employer: { select: { companyName: true, logoUrl: true, city: true } } },
                orderBy: [{ boostedUntil: 'desc' }, { createdAt: 'desc' }],
                skip,
                take: limit,
            }),
            prisma_1.default.vacancy.count({ where }),
        ]);
        (0, response_1.ok)(res, { data: vacancies, total, page, totalPages: Math.ceil(total / limit) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getMapVacancies(req, res) {
    try {
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: { isActive: true, isModerated: true, lat: { not: null }, lng: { not: null } },
            select: {
                id: true, title: true, city: true,
                salaryMin: true, salaryMax: true,
                lat: true, lng: true,
                employer: { select: { companyName: true } },
            },
            take: 200,
        });
        (0, response_1.ok)(res, { vacancies });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getEmployerVacancies(req, res) {
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.ok)(res, { vacancies: [] });
            return;
        }
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: { employerId: employer.id },
            include: { _count: { select: { applications: true } } },
            orderBy: { createdAt: 'desc' },
        });
        (0, response_1.ok)(res, { vacancies });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function aiGenerateDescription(req, res) {
    const { title, requirements, conditions } = req.body;
    if (!title) {
        (0, response_1.fail)(res, 'title is required');
        return;
    }
    try {
        const description = await (0, groq_service_1.generateVacancyDescription)({ title, requirements, conditions });
        (0, response_1.ok)(res, { description });
    }
    catch (e) {
        (0, response_1.fail)(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getVacancy(req, res) {
    const { id } = req.params;
    try {
        const vacancy = await prisma_1.default.vacancy.findUnique({
            where: { id },
            include: { employer: true },
        });
        if (!vacancy || !vacancy.isModerated) {
            (0, response_1.fail)(res, 'Vacancy not found');
            return;
        }
        await prisma_1.default.vacancy.update({ where: { id }, data: { viewCount: { increment: 1 } } });
        const similar = await prisma_1.default.vacancy.findMany({
            where: {
                isActive: true,
                isModerated: true,
                id: { not: id },
                OR: [
                    ...(vacancy.employmentType ? [{ employmentType: vacancy.employmentType }] : []),
                    ...(vacancy.city ? [{ city: vacancy.city }] : []),
                ],
            },
            include: { employer: { select: { companyName: true, logoUrl: true } } },
            take: 5,
        });
        (0, response_1.ok)(res, { vacancy, similar });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function createVacancy(req, res) {
    const { title, description, salaryMin, salaryMax, city, lat, lng, employmentType, experience } = req.body;
    if (!title || !description) {
        (0, response_1.fail)(res, 'title and description are required');
        return;
    }
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.fail)(res, 'Employer profile not found. Please complete your profile first.');
            return;
        }
        const vacancy = await prisma_1.default.vacancy.create({
            data: {
                employerId: employer.id,
                title,
                description,
                salaryMin: salaryMin ? parseInt(salaryMin) : null,
                salaryMax: salaryMax ? parseInt(salaryMax) : null,
                city: city ?? null,
                lat: lat ? parseFloat(lat) : null,
                lng: lng ? parseFloat(lng) : null,
                employmentType: employmentType ?? null,
                experience: experience ?? null,
            },
        });
        (0, response_1.ok)(res, { vacancy });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function updateVacancy(req, res) {
    const { id } = req.params;
    const { isActive, title, description, salaryMin, salaryMax, city, employmentType, experience } = req.body;
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.fail)(res, 'Employer profile not found');
            return;
        }
        const existing = await prisma_1.default.vacancy.findUnique({ where: { id } });
        if (!existing || existing.employerId !== employer.id) {
            (0, response_1.fail)(res, 'Vacancy not found or access denied');
            return;
        }
        const vacancy = await prisma_1.default.vacancy.update({
            where: { id },
            data: {
                ...(isActive !== undefined ? { isActive } : {}),
                ...(title !== undefined ? { title } : {}),
                ...(description !== undefined ? { description } : {}),
                ...(salaryMin !== undefined ? { salaryMin: Number(salaryMin) } : {}),
                ...(salaryMax !== undefined ? { salaryMax: Number(salaryMax) } : {}),
                ...(city !== undefined ? { city } : {}),
                ...(employmentType !== undefined ? { employmentType } : {}),
                ...(experience !== undefined ? { experience } : {}),
            },
        });
        (0, response_1.ok)(res, { vacancy });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function deleteVacancy(req, res) {
    const { id } = req.params;
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.fail)(res, 'Employer profile not found');
            return;
        }
        const existing = await prisma_1.default.vacancy.findUnique({ where: { id } });
        if (!existing || existing.employerId !== employer.id) {
            (0, response_1.fail)(res, 'Vacancy not found or access denied');
            return;
        }
        await prisma_1.default.vacancy.delete({ where: { id } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function applyToVacancy(req, res) {
    const { id: vacancyId } = req.params;
    const { resumeId, coverLetter } = req.body;
    if (!resumeId) {
        (0, response_1.fail)(res, 'resumeId is required');
        return;
    }
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found. Please complete your profile first.');
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Vacancy not found');
            return;
        }
        const application = await prisma_1.default.application.create({
            data: {
                resumeId,
                vacancyId,
                seekerId: seeker.id,
                employerId: vacancy.employerId,
                coverLetter: coverLetter ?? null,
            },
        });
        // Notify employer
        const employer = await prisma_1.default.employer.findUnique({
            where: { id: vacancy.employerId },
            select: { userId: true },
        });
        if (employer) {
            const name = [seeker.firstName, seeker.lastName].filter(Boolean).join(' ') || 'Соискатель';
            await prisma_1.default.notification.create({
                data: {
                    userId: employer.userId,
                    type: 'NEW_APPLICATION',
                    text: `${name} откликнулся на вакансию «${vacancy.title}»`,
                },
            });
        }
        (0, response_1.ok)(res, { application });
    }
    catch (e) {
        if (e?.code === 'P2002') {
            (0, response_1.fail)(res, 'Вы уже откликались на эту вакансию');
            return;
        }
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
