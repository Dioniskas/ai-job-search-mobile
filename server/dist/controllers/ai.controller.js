"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiInterviewPrep = aiInterviewPrep;
exports.aiInterviewFeedback = aiInterviewFeedback;
exports.aiMatchPercent = aiMatchPercent;
exports.aiMatchVacancies = aiMatchVacancies;
exports.aiMatchResumes = aiMatchResumes;
exports.aiCoverLetter = aiCoverLetter;
exports.aiSalaryEstimate = aiSalaryEstimate;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const match_service_1 = require("../services/ai/match.service");
const groq_service_1 = require("../services/ai/groq.service");
function resumeToText(r) {
    const c = (typeof r.content === 'object' && r.content !== null && !Array.isArray(r.content))
        ? r.content
        : {};
    return [
        `Должность: ${r.title}`,
        c['summary'] ? `О себе: ${c['summary']}` : '',
        c['experience'] ? `Опыт: ${c['experience']}` : '',
        c['education'] ? `Образование: ${c['education']}` : '',
        r.skills.length ? `Навыки: ${r.skills.join(', ')}` : '',
        c['languages'] ? `Языки: ${c['languages']}` : '',
        r.experience ? `Стаж: ${r.experience}` : '',
        c['rawText'] ? `Текст резюме: ${c['rawText']}` : '',
    ].filter(Boolean).join('\n');
}
function vacancyToText(v) {
    return [
        `Должность: ${v.title}`,
        `Описание: ${v.description}`,
        v.employmentType ? `Тип занятости: ${v.employmentType}` : '',
        v.experience ? `Требуемый опыт: ${v.experience}` : '',
        v.city ? `Город: ${v.city}` : '',
    ].filter(Boolean).join('\n');
}
// ── POST /api/ai/interview-prep ───────────────────────────────────────────────
async function aiInterviewPrep(req, res) {
    const { vacancyTitle, vacancyDescription, vacancyId } = req.body;
    let title = vacancyTitle?.trim() ?? '';
    let description = vacancyDescription?.trim() ?? '';
    if (vacancyId && !title) {
        try {
            const vacancy = await prisma_1.default.vacancy.findUnique({
                where: { id: vacancyId },
                select: { title: true, description: true },
            });
            if (vacancy) {
                title = vacancy.title;
                description = vacancy.description;
            }
        }
        catch {
            // fall through
        }
    }
    if (!title) {
        (0, response_1.fail)(res, 'vacancyTitle обязателен');
        return;
    }
    try {
        const questions = await (0, groq_service_1.generateInterviewQuestions)({ vacancyTitle: title, vacancyDescription: description || undefined });
        (0, response_1.ok)(res, { questions, vacancyTitle: title });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/interview-feedback ──────────────────────────────────────────
async function aiInterviewFeedback(req, res) {
    const { question, answer, vacancyTitle } = req.body;
    if (!question || !answer || !vacancyTitle) {
        (0, response_1.fail)(res, 'question, answer и vacancyTitle обязательны');
        return;
    }
    if (answer.trim().length < 5) {
        (0, response_1.fail)(res, 'Ответ слишком короткий');
        return;
    }
    try {
        const result = await (0, groq_service_1.evaluateInterviewAnswer)({ question, answer, vacancyTitle });
        (0, response_1.ok)(res, result);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/match-percent ────────────────────────────────────────────────
async function aiMatchPercent(req, res) {
    const { resumeId, vacancyId } = req.body;
    if (!resumeId || !vacancyId) {
        (0, response_1.fail)(res, 'resumeId и vacancyId обязательны');
        return;
    }
    try {
        const [resume, vacancy] = await Promise.all([
            prisma_1.default.resume.findUnique({ where: { id: resumeId } }),
            prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } }),
        ]);
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено');
            return;
        }
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена');
            return;
        }
        const result = await (0, match_service_1.matchPercent)(resumeToText(resume), vacancyToText(vacancy));
        (0, response_1.ok)(res, result);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/match-vacancies ──────────────────────────────────────────────
async function aiMatchVacancies(req, res) {
    const { resumeId } = req.body;
    if (!resumeId) {
        (0, response_1.fail)(res, 'resumeId обязателен');
        return;
    }
    try {
        const resume = await prisma_1.default.resume.findUnique({ where: { id: resumeId } });
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено');
            return;
        }
        const vacancies = await prisma_1.default.vacancy.findMany({
            where: { isActive: true },
            include: { employer: { select: { companyName: true, logoUrl: true, city: true } } },
            orderBy: { createdAt: 'desc' },
            take: 20,
        });
        const matches = await (0, match_service_1.matchVacancies)(resumeToText(resume), vacancies.map(v => ({
            id: v.id,
            title: v.title,
            description: v.description,
            employmentType: v.employmentType,
            experience: v.experience,
        })));
        const vacancyMap = new Map(vacancies.map(v => [v.id, v]));
        const enriched = matches
            .map(m => ({ ...m, vacancy: vacancyMap.get(m.vacancyId) ?? null }))
            .filter(m => m.vacancy !== null);
        (0, response_1.ok)(res, { matches: enriched });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/match-resumes ────────────────────────────────────────────────
async function aiMatchResumes(req, res) {
    const { vacancyId } = req.body;
    if (!vacancyId) {
        (0, response_1.fail)(res, 'vacancyId обязателен');
        return;
    }
    try {
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена');
            return;
        }
        const resumes = await prisma_1.default.resume.findMany({
            include: {
                seeker: {
                    select: { firstName: true, lastName: true, city: true, photoUrl: true },
                },
            },
            orderBy: { updatedAt: 'desc' },
            take: 20,
        });
        const matches = await (0, match_service_1.matchResumes)(vacancyToText(vacancy), resumes.map(r => ({
            id: r.id,
            title: r.title,
            skills: r.skills,
            experience: r.experience,
        })));
        const resumeMap = new Map(resumes.map(r => [r.id, r]));
        const enriched = matches
            .map(m => ({ ...m, resume: resumeMap.get(m.resumeId) ?? null }))
            .filter(m => m.resume !== null);
        (0, response_1.ok)(res, { matches: enriched });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/cover-letter ─────────────────────────────────────────────────
async function aiCoverLetter(req, res) {
    const { resumeId, vacancyId } = req.body;
    if (!resumeId || !vacancyId) {
        (0, response_1.fail)(res, 'resumeId и vacancyId обязательны');
        return;
    }
    try {
        const [resume, vacancy] = await Promise.all([
            prisma_1.default.resume.findUnique({ where: { id: resumeId } }),
            prisma_1.default.vacancy.findUnique({ where: { id: vacancyId } }),
        ]);
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено');
            return;
        }
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена');
            return;
        }
        const coverLetter = await (0, match_service_1.generateCoverLetter)(resumeToText(resume), vacancyToText(vacancy));
        (0, response_1.ok)(res, { coverLetter });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
// ── POST /api/ai/salary-estimate ──────────────────────────────────────────────
async function aiSalaryEstimate(req, res) {
    const { resumeId } = req.body;
    if (!resumeId) {
        (0, response_1.fail)(res, 'resumeId обязателен');
        return;
    }
    try {
        const resume = await prisma_1.default.resume.findUnique({ where: { id: resumeId } });
        if (!resume) {
            (0, response_1.fail)(res, 'Резюме не найдено');
            return;
        }
        const estimate = await (0, match_service_1.estimateSalary)(resumeToText(resume));
        (0, response_1.ok)(res, estimate);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
    }
}
