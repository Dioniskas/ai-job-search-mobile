"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.improveResume = improveResume;
exports.generateResumeFromForm = generateResumeFromForm;
exports.generateResumeFromTranscript = generateResumeFromTranscript;
exports.generateVacancyDescription = generateVacancyDescription;
exports.generateInterviewQuestions = generateInterviewQuestions;
exports.evaluateInterviewAnswer = evaluateInterviewAnswer;
exports.scoreResume = scoreResume;
exports.transcribeAudio = transcribeAudio;
const openai_1 = __importStar(require("openai"));
const groq = new openai_1.default({
    apiKey: process.env.GROQ_API_KEY,
    baseURL: 'https://api.groq.com/openai/v1',
});
const SYSTEM_RESUME = `Отвечай ТОЛЬКО на русском языке. Весь текст резюме должен быть на русском.

Ты — профессиональный составитель резюме в стиле HH.ru. Отвечай ТОЛЬКО валидным JSON без markdown и лишнего текста.

Верни объект со следующими полями:
  title (string): желаемая должность — конкретно и профессионально (например, "Senior Frontend Developer", "Шеф-повар", "Менеджер по продажам")
  summary (string): раздел "О себе" — 2-3 предложения: кто ты, твои ключевые компетенции и сильные стороны. Конкретно, без воды.
  experience (string): опыт работы в обратном хронологическом порядке. Для каждого места работы укажи: название компании, должность, период работы (месяц/год — месяц/год), основные обязанности и достижения с цифрами (увеличил продажи на X%, сократил время на Y%). Разделяй блоки пустой строкой.
  education (string): образование — учебное заведение, специальность, год окончания. Если несколько — в обратном хронологическом порядке.
  skills (array of strings): ключевые профессиональные навыки — конкретные, не банальные (не "работа в команде", а "React 18", "управление командой до 15 человек", "1С:Бухгалтерия"). 8-12 навыков.
  languages (string): иностранные языки с уровнем по CEFR: "Английский — B2 (Upper-Intermediate)", "Немецкий — A1". Если неизвестно — пустая строка.
  additional (string): дополнительная информация — курсы, сертификаты, готовность к командировкам/переезду. Если нечего добавить — пустая строка.

Резюме должно быть конкретным, лаконичным, с акцентом на достижения и цифры. Избегай клише и общих фраз.`;
function parseResumeJson(raw) {
    try {
        const parsed = JSON.parse(raw);
        return {
            title: parsed.title ?? 'Специалист',
            summary: parsed.summary ?? '',
            experience: parsed.experience ?? '',
            education: parsed.education ?? '',
            skills: Array.isArray(parsed.skills) ? parsed.skills : [],
            languages: parsed.languages ?? '',
            additional: parsed.additional ?? '',
        };
    }
    catch {
        return { title: 'Специалист', summary: raw.slice(0, 500), experience: '', education: '', skills: [] };
    }
}
async function chatJson(userPrompt) {
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        response_format: { type: 'json_object' },
        messages: [
            { role: 'system', content: SYSTEM_RESUME },
            { role: 'user', content: userPrompt },
        ],
        max_tokens: 2000,
    });
    return parseResumeJson(resp.choices[0].message.content ?? '{}');
}
async function improveResume(rawText) {
    return chatJson(`Улучши и структурируй следующий текст резюме в профессиональное резюме в стиле HH.ru:\n\n${rawText.slice(0, 6000)}`);
}
async function generateResumeFromForm(data) {
    const prompt = [
        `Составь профессиональное резюме для:`,
        `Имя: ${data.name}`,
        data.age ? `Возраст: ${data.age}` : '',
        `Опыт работы: ${data.experience}`,
        `Навыки: ${data.skills}`,
        data.about ? `Дополнительно: ${data.about}` : '',
    ].filter(Boolean).join('\n');
    return chatJson(prompt);
}
async function generateResumeFromTranscript(transcript) {
    return chatJson(`Ниже — устный рассказ человека о своём профессиональном опыте. Составь по нему профессиональное резюме в стиле HH.ru:\n\n${transcript.slice(0, 4000)}`);
}
async function generateVacancyDescription(data) {
    const parts = [
        `Составь привлекательное описание вакансии для должности: ${data.title}.`,
        data.requirements ? `Требования к кандидату: ${data.requirements}` : '',
        data.conditions ? `Условия работы: ${data.conditions}` : '',
        'Опиши подробно обязанности, требования и условия. Текст должен быть живым, профессиональным и мотивирующим. Верни только текст описания без заголовков и markdown.',
    ].filter(Boolean).join('\n');
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        messages: [
            { role: 'system', content: 'Ты опытный HR-менеджер. Пишешь привлекательные описания вакансий на русском языке.' },
            { role: 'user', content: parts },
        ],
        max_tokens: 800,
    });
    return resp.choices[0].message.content ?? '';
}
// ── Interview prep ────────────────────────────────────────────────────────────
async function generateInterviewQuestions(data) {
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        response_format: { type: 'json_object' },
        messages: [
            {
                role: 'system',
                content: 'Отвечай ТОЛЬКО на русском языке. Ты — опытный HR-менеджер и интервьюер. Верни JSON-объект с полем "questions" — массивом ровно из 5 строк. Каждый вопрос должен быть конкретным, профессиональным и релевантным для позиции. Чередуй технические, поведенческие и ситуационные вопросы.',
            },
            {
                role: 'user',
                content: [
                    `Составь 5 вопросов для собеседования на позицию: ${data.vacancyTitle}`,
                    data.vacancyDescription ? `Описание вакансии:\n${data.vacancyDescription.slice(0, 1000)}` : '',
                ]
                    .filter(Boolean)
                    .join('\n\n'),
            },
        ],
        max_tokens: 800,
    });
    try {
        const parsed = JSON.parse(resp.choices[0].message.content ?? '{}');
        const qs = parsed.questions;
        if (Array.isArray(qs) && qs.length > 0) {
            return qs.slice(0, 5);
        }
    }
    catch {
        // fall through
    }
    return [
        'Расскажите о вашем опыте работы на аналогичной позиции.',
        'Какие ваши сильные стороны помогут вам на этой должности?',
        'Опишите сложную рабочую ситуацию и как вы её решили.',
        'Какие профессиональные цели вы ставите на ближайшие 2–3 года?',
        'Почему вы хотите работать именно в нашей компании?',
    ];
}
async function evaluateInterviewAnswer(data) {
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        response_format: { type: 'json_object' },
        messages: [
            {
                role: 'system',
                content: 'Отвечай ТОЛЬКО на русском языке. Ты — опытный HR-интервьюер. Оцени ответ кандидата на вопрос собеседования. Верни JSON-объект с полями: "feedback" (string, 2–4 предложения с конструктивной обратной связью), "score" (number, от 1 до 10), "tips" (array of 2–3 строк с советами по улучшению ответа).',
            },
            {
                role: 'user',
                content: `Вакансия: ${data.vacancyTitle}\n\nВопрос: ${data.question}\n\nОтвет кандидата: ${data.answer.slice(0, 2000)}`,
            },
        ],
        max_tokens: 600,
    });
    try {
        const parsed = JSON.parse(resp.choices[0].message.content ?? '{}');
        return {
            feedback: parsed.feedback ?? 'Ответ принят.',
            score: typeof parsed.score === 'number' ? Math.max(1, Math.min(10, parsed.score)) : 5,
            tips: Array.isArray(parsed.tips) ? parsed.tips.slice(0, 3) : [],
        };
    }
    catch {
        return { feedback: 'Ответ принят.', score: 5, tips: [] };
    }
}
async function scoreResume(content) {
    const resp = await groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        response_format: { type: 'json_object' },
        messages: [
            {
                role: 'system',
                content: 'Ты — эксперт по оценке резюме. Оцени резюме по шкале от 0 до 100. Верни JSON: "score" (число), "strengths" (массив 2–3 строки — сильные стороны), "improvements" (массив 2–3 строки — что улучшить), "summary" (строка, 1–2 предложения с общей оценкой). Отвечай только на русском.',
            },
            {
                role: 'user',
                content: [
                    `Должность: ${content.title}`,
                    `О себе: ${content.summary}`,
                    `Опыт: ${content.experience.slice(0, 1000)}`,
                    `Навыки: ${content.skills.join(', ')}`,
                    `Образование: ${content.education}`,
                ].join('\n'),
            },
        ],
        max_tokens: 500,
    });
    try {
        const parsed = JSON.parse(resp.choices[0].message.content ?? '{}');
        return {
            score: typeof parsed.score === 'number' ? Math.max(0, Math.min(100, Math.round(parsed.score))) : 60,
            strengths: Array.isArray(parsed.strengths) ? parsed.strengths.slice(0, 3) : [],
            improvements: Array.isArray(parsed.improvements) ? parsed.improvements.slice(0, 3) : [],
            summary: parsed.summary ?? '',
        };
    }
    catch {
        return { score: 60, strengths: [], improvements: [], summary: '' };
    }
}
// ── Transcription ──────────────────────────────────────────────────────────────
async function transcribeAudio(buffer, mimetype) {
    const ext = mimetype.includes('webm') ? 'webm'
        : mimetype.includes('ogg') ? 'ogg'
            : mimetype.includes('mp4') ? 'mp4'
                : mimetype.includes('wav') ? 'wav'
                    : 'webm';
    const audioFile = await (0, openai_1.toFile)(buffer, `recording.${ext}`, { type: mimetype });
    const transcription = await groq.audio.transcriptions.create({
        file: audioFile,
        model: 'whisper-large-v3',
        language: 'ru',
    });
    return transcription.text;
}
