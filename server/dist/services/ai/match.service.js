"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.matchPercent = matchPercent;
exports.matchVacancies = matchVacancies;
exports.matchResumes = matchResumes;
exports.generateCoverLetter = generateCoverLetter;
exports.estimateSalary = estimateSalary;
const openai_1 = __importDefault(require("openai"));
const groq = new openai_1.default({
    apiKey: process.env.GROQ_API_KEY,
    baseURL: 'https://api.groq.com/openai/v1',
});
const SYSTEM = 'Ты — ИИ-рекрутер. Отвечай ТОЛЬКО валидным JSON без markdown и лишнего текста. Все пояснения пиши на русском языке.';
async function chatJson(prompt, maxTokens = 600) {
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        response_format: { type: 'json_object' },
        messages: [
            { role: 'system', content: SYSTEM },
            { role: 'user', content: prompt },
        ],
        max_tokens: maxTokens,
    });
    return JSON.parse(resp.choices[0].message.content ?? '{}');
}
async function matchPercent(resumeText, vacancyText) {
    const prompt = `Оцени процент совпадения резюме с вакансией от 0 до 100.

РЕЗЮМЕ:
${resumeText.slice(0, 2000)}

ВАКАНСИЯ:
${vacancyText.slice(0, 1000)}

Верни JSON: { "percent": <число 0-100>, "explanation": "<1-2 предложения обоснования>" }`;
    try {
        const data = chatJson(prompt, 300);
        const d = await data;
        return {
            percent: Math.min(100, Math.max(0, Number(d.percent) || 0)),
            explanation: String(d.explanation ?? ''),
        };
    }
    catch {
        return { percent: 0, explanation: 'Не удалось рассчитать совпадение' };
    }
}
async function matchVacancies(resumeText, vacancies) {
    if (vacancies.length === 0)
        return [];
    const list = vacancies.map((v, i) => `${i + 1}. id="${v.id}" | "${v.title}" | ${v.description.slice(0, 250)}`).join('\n');
    const prompt = `Подбери вакансии, подходящие для этого резюме. Оцени % совпадения.

РЕЗЮМЕ:
${resumeText.slice(0, 2000)}

ВАКАНСИИ:
${list}

Верни JSON: { "matches": [ { "vacancyId": "...", "percent": <0-100>, "reason": "<кратко>" }, ... ] }
Включай только вакансии с процентом >= 20. Сортируй от большего к меньшему.`;
    try {
        const data = await chatJson(prompt, 1500);
        return (data.matches ?? []).map(m => ({
            vacancyId: String(m['vacancyId'] ?? ''),
            percent: Math.min(100, Math.max(0, Number(m['percent']) || 0)),
            reason: String(m['reason'] ?? ''),
        }));
    }
    catch {
        return [];
    }
}
async function matchResumes(vacancyText, resumes) {
    if (resumes.length === 0)
        return [];
    const list = resumes.map((r, i) => `${i + 1}. id="${r.id}" | "${r.title}" | Навыки: ${r.skills.slice(0, 8).join(', ')} | Опыт: ${r.experience ?? 'не указан'}`).join('\n');
    const prompt = `Подбери кандидатов, подходящих для этой вакансии. Оцени % совпадения.

ВАКАНСИЯ:
${vacancyText.slice(0, 1000)}

РЕЗЮМЕ КАНДИДАТОВ:
${list}

Верни JSON: { "matches": [ { "resumeId": "...", "percent": <0-100>, "reason": "<кратко>" }, ... ] }
Включай только кандидатов с процентом >= 20. Сортируй от большего к меньшему.`;
    try {
        const data = await chatJson(prompt, 1500);
        return (data.matches ?? []).map(m => ({
            resumeId: String(m['resumeId'] ?? ''),
            percent: Math.min(100, Math.max(0, Number(m['percent']) || 0)),
            reason: String(m['reason'] ?? ''),
        }));
    }
    catch {
        return [];
    }
}
// ── Сопроводительное письмо ───────────────────────────────────────────────────
async function generateCoverLetter(resumeText, vacancyText) {
    const prompt = `Напиши профессиональное сопроводительное письмо на русском языке для отклика на вакансию. 2-3 абзаца, конкретно и персонализированно.

РЕЗЮМЕ:
${resumeText.slice(0, 2000)}

ВАКАНСИЯ:
${vacancyText.slice(0, 800)}

Верни JSON: { "coverLetter": "<текст письма>" }`;
    try {
        const data = await chatJson(prompt, 600);
        return String(data.coverLetter ?? '');
    }
    catch {
        return '';
    }
}
async function estimateSalary(resumeText) {
    const prompt = `Оцени рыночную зарплату специалиста в Ташкенте, Узбекистан. Используй актуальные данные рынка труда. Зарплата в узбекских сумах.

РЕЗЮМЕ:
${resumeText.slice(0, 2000)}

Верни JSON: { "min": <число>, "max": <число>, "currency": "сум", "explanation": "<2-3 предложения обоснования>" }`;
    try {
        const data = await chatJson(prompt, 400);
        return {
            min: Math.max(0, Number(data.min) || 0),
            max: Math.max(0, Number(data.max) || 0),
            currency: String(data.currency ?? 'сум'),
            explanation: String(data.explanation ?? ''),
        };
    }
    catch {
        return { min: 0, max: 0, currency: 'сум', explanation: 'Не удалось рассчитать' };
    }
}
