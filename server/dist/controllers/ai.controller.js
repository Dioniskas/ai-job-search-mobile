"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateRejectionReason = generateRejectionReason;
exports.interviewPrep = interviewPrep;
exports.interviewFeedback = interviewFeedback;
exports.matchPercent = matchPercent;
exports.matchVacancies = matchVacancies;
exports.matchResumes = matchResumes;
exports.coverLetter = coverLetter;
exports.salaryEstimate = salaryEstimate;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const groq_service_1 = require("../services/ai/groq.service");
async function generateRejectionReason(req, res) {
    try {
        const { userId, role } = req.user;
        if (role !== 'EMPLOYER') {
            (0, response_1.fail)(res, 'Доступ запрещён', 403);
            return;
        }
        const { applicationId } = req.body;
        if (!applicationId) {
            (0, response_1.fail)(res, 'applicationId обязателен');
            return;
        }
        const application = await prisma_1.default.application.findUnique({
            where: { id: applicationId },
            include: {
                employer: { select: { userId: true, companyName: true } },
                seeker: { select: { firstName: true, lastName: true } },
                vacancy: { select: { title: true } },
            },
        });
        if (!application) {
            (0, response_1.fail)(res, 'Отклик не найден', 404);
            return;
        }
        if (application.employer.userId !== userId) {
            (0, response_1.fail)(res, 'Доступ запрещён', 403);
            return;
        }
        const text = await (0, groq_service_1.generateRejection)({
            companyName: application.employer.companyName,
            seekerName: `${application.seeker.firstName} ${application.seeker.lastName}`,
            vacancyTitle: application.vacancy.title,
        });
        (0, response_1.ok)(res, { text });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function interviewPrep(req, res) {
    try {
        const { vacancyTitle, vacancyDescription, vacancyId } = req.body;
        let title = vacancyTitle?.trim() ?? '';
        let description = vacancyDescription?.trim() ?? '';
        if (vacancyId && !title) {
            const vacancy = await prisma_1.default.vacancy.findUnique({
                where: { id: vacancyId },
                select: { title: true, description: true },
            });
            if (vacancy) {
                title = vacancy.title;
                description = vacancy.description;
            }
        }
        if (!title) {
            (0, response_1.fail)(res, 'vacancyTitle обязателен');
            return;
        }
        const questions = await (0, groq_service_1.generateInterviewQuestions)({ vacancyTitle: title, vacancyDescription: description || undefined });
        (0, response_1.ok)(res, { questions, vacancyTitle: title });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function interviewFeedback(req, res) {
    try {
        const { question, answer, vacancyTitle } = req.body;
        if (!question || !answer || !vacancyTitle) {
            (0, response_1.fail)(res, 'question, answer и vacancyTitle обязательны');
            return;
        }
        if (answer.trim().length < 5) {
            (0, response_1.fail)(res, 'Ответ слишком короткий');
            return;
        }
        const result = await (0, groq_service_1.evaluateInterviewAnswer)({ question, answer, vacancyTitle });
        (0, response_1.ok)(res, result);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Match percent ──────────────────────────────────────────────────────────────
async function matchPercent(req, res) {
    try {
        const { resumeId, vacancyId } = req.body;
        if (!resumeId || !vacancyId) {
            (0, response_1.fail)(res, 'resumeId и vacancyId обязательны');
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль соискателя не найден', 404);
            return;
        }
        const [resume, vacancy] = await Promise.all([
            prisma_1.default.resume.findFirst({
                where: { id: resumeId, seekerId: seeker.id },
            }),
            prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } }),
        ]);
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено', 404);
            return;
        }
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        const content = resume.content;
        const result = await (0, groq_service_1.calculateMatchPercent)({
            resumeTitle: resume.title,
            resumeSkills: resume.skills,
            resumeExperience: resume.experience ?? '',
            vacancyTitle: vacancy.title,
            vacancyDescription: vacancy.description,
        });
        // Update matchPercent in application if exists
        await prisma_1.default.application.updateMany({
            where: { resumeId, vacancyId, seekerId: seeker.id },
            data: { matchPercent: result.percent },
        }).catch(() => null);
        (0, response_1.ok)(res, { percent: result.percent, explanation: result.explanation });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Match vacancies for a resume ───────────────────────────────────────────────
async function matchVacancies(req, res) {
    try {
        const { resumeId } = req.body;
        if (!resumeId) {
            (0, response_1.fail)(res, 'resumeId обязателен');
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const resume = await prisma_1.default.resume.findFirst({
            where: { id: resumeId, seekerId: seeker.id },
        });
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено', 404);
            return;
        }
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: { isActive: true },
            include: {
                employer: { select: { companyName: true, logoUrl: true } },
            },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });
        const resumeText = [resume.title, ...resume.skills, resume.experience ?? ''].join(' ');
        const scored = vacancies
            .map((v) => {
            const vacancyText = `${v.title} ${v.description}`;
            const percent = (0, groq_service_1.keywordScore)(resumeText, vacancyText);
            return {
                percent,
                reason: percent >= 60
                    ? 'Хорошее совпадение по навыкам и опыту'
                    : percent >= 35
                        ? 'Частичное совпадение'
                        : 'Низкое совпадение',
                vacancy: v,
            };
        })
            .filter((m) => m.percent >= 15)
            .sort((a, b) => b.percent - a.percent)
            .slice(0, 15);
        (0, response_1.ok)(res, { matches: scored });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Match resumes for a vacancy ────────────────────────────────────────────────
async function matchResumes(req, res) {
    try {
        const { vacancyId } = req.body;
        if (!vacancyId) {
            (0, response_1.fail)(res, 'vacancyId обязателен');
            return;
        }
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findFirst({
            where: { id: vacancyId, employerId: employer.id },
        });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        const resumes = await prisma_1.default.resume.findMany({
            include: {
                seeker: {
                    select: {
                        firstName: true,
                        lastName: true,
                        photoUrl: true,
                        city: true,
                        isVisible: true,
                    },
                },
            },
            orderBy: { updatedAt: 'desc' },
            take: 100,
        });
        const vacancyText = `${vacancy.title} ${vacancy.description}`;
        const scored = resumes
            .filter((r) => r.seeker.isVisible)
            .map((r) => {
            const resumeText = [r.title, ...r.skills, r.experience ?? ''].join(' ');
            const percent = (0, groq_service_1.keywordScore)(resumeText, vacancyText);
            return {
                percent,
                reason: percent >= 60
                    ? 'Хорошее совпадение по навыкам'
                    : percent >= 35
                        ? 'Частичное совпадение'
                        : 'Низкое совпадение',
                resume: r,
            };
        })
            .filter((m) => m.percent >= 10)
            .sort((a, b) => b.percent - a.percent)
            .slice(0, 15);
        (0, response_1.ok)(res, { matches: scored });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Cover letter ───────────────────────────────────────────────────────────────
async function coverLetter(req, res) {
    try {
        const { resumeId, vacancyId } = req.body;
        if (!resumeId || !vacancyId) {
            (0, response_1.fail)(res, 'resumeId и vacancyId обязательны');
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const [resume, vacancy] = await Promise.all([
            prisma_1.default.resume.findFirst({ where: { id: resumeId, seekerId: seeker.id } }),
            prisma_1.default.vacancy.findUnique({
                where: { id: vacancyId },
                include: { employer: { select: { companyName: true } } },
            }),
        ]);
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено', 404);
            return;
        }
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        const content = resume.content;
        const letter = await (0, groq_service_1.generateCoverLetter)({
            seekerName: `${seeker.firstName} ${seeker.lastName}`,
            resumeTitle: resume.title,
            resumeSkills: resume.skills,
            resumeSummary: content['summary'] ?? '',
            vacancyTitle: vacancy.title,
            companyName: vacancy.employer.companyName,
        });
        (0, response_1.ok)(res, { coverLetter: letter });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Salary estimate ────────────────────────────────────────────────────────────
async function salaryEstimate(req, res) {
    try {
        const { resumeId } = req.body;
        if (!resumeId) {
            (0, response_1.fail)(res, 'resumeId обязателен');
            return;
        }
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const resume = await prisma_1.default.resume.findFirst({
            where: { id: resumeId, seekerId: seeker.id },
        });
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено', 404);
            return;
        }
        const estimate = await (0, groq_service_1.estimateSalary)({
            title: resume.title,
            skills: resume.skills,
            experience: resume.experience ?? '',
        });
        (0, response_1.ok)(res, estimate);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
