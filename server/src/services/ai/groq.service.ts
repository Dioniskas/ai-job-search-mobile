import OpenAI, { toFile } from 'openai';

const groq = new OpenAI({
  apiKey: process.env.GROQ_API_KEY,
  baseURL: 'https://api.groq.com/openai/v1',
});

export interface ResumeContent {
  title: string;
  summary: string;
  experience: string;
  education: string;
  skills: string[];
  languages?: string;
  additional?: string;
  rawText?: string;
}

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

function parseResumeJson(raw: string): ResumeContent {
  try {
    const parsed = JSON.parse(raw) as Partial<ResumeContent>;
    return {
      title:      parsed.title      ?? 'Специалист',
      summary:    parsed.summary    ?? '',
      experience: parsed.experience ?? '',
      education:  parsed.education  ?? '',
      skills:     Array.isArray(parsed.skills) ? parsed.skills : [],
      languages:  parsed.languages  ?? '',
      additional: parsed.additional ?? '',
    };
  } catch {
    return { title: 'Специалист', summary: raw.slice(0, 500), experience: '', education: '', skills: [] };
  }
}

async function chatJson(userPrompt: string): Promise<ResumeContent> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: SYSTEM_RESUME },
      { role: 'user',   content: userPrompt },
    ],
    max_tokens: 2000,
  });
  return parseResumeJson(resp.choices[0].message.content ?? '{}');
}

export async function improveResume(rawText: string): Promise<ResumeContent> {
  return chatJson(
    `Улучши и структурируй следующий текст резюме в профессиональное резюме в стиле HH.ru:\n\n${rawText.slice(0, 6000)}`
  );
}

export async function generateResumeFromForm(data: {
  name: string;
  age?: string;
  experience: string;
  skills: string;
  about?: string;
}): Promise<ResumeContent> {
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

export async function generateResumeFromTranscript(transcript: string): Promise<ResumeContent> {
  return chatJson(
    `Ниже — устный рассказ человека о своём профессиональном опыте. Составь по нему профессиональное резюме в стиле HH.ru:\n\n${transcript.slice(0, 4000)}`
  );
}

export async function generateRejection(data: {
  companyName: string;
  seekerName: string;
  vacancyTitle: string;
}): Promise<string> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'system',
        content:
          'Ты — HR-менеджер. Пиши вежливые, тёплые и профессиональные письма об отказе на русском языке. Письмо должно быть коротким (3-4 предложения), уважительным и оставлять позитивное впечатление. Без лишних объяснений и извинений.',
      },
      {
        role: 'user',
        content: `Напиши вежливый отказ кандидату.\nКомпания: ${data.companyName}\nКандидат: ${data.seekerName}\nВакансия: ${data.vacancyTitle}\nВерни только текст сообщения, без приветствия "Уважаемый/ая" и подписи.`,
      },
    ],
    max_tokens: 300,
  });
  return (resp.choices[0].message.content ?? '').trim();
}

export async function generateInterviewQuestions(data: {
  vacancyTitle: string;
  vacancyDescription?: string;
}): Promise<string[]> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'Отвечай ТОЛЬКО на русском языке. Ты — опытный HR-менеджер и интервьюер. Верни JSON-объект с полем "questions" — массивом ровно из 5 строк. Каждый вопрос должен быть конкретным, профессиональным и релевантным для позиции. Чередуй технические, поведенческие и ситуационные вопросы.',
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
    const parsed = JSON.parse(resp.choices[0].message.content ?? '{}') as { questions?: unknown };
    const qs = parsed.questions;
    if (Array.isArray(qs) && qs.length > 0) {
      return (qs as string[]).slice(0, 5);
    }
  } catch {
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

export interface InterviewFeedback {
  feedback: string;
  score: number;
  tips: string[];
}

export async function evaluateInterviewAnswer(data: {
  question: string;
  answer: string;
  vacancyTitle: string;
}): Promise<InterviewFeedback> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'Отвечай ТОЛЬКО на русском языке. Ты — опытный HR-интервьюер. Оцени ответ кандидата на вопрос собеседования. Верни JSON-объект с полями: "feedback" (string, 2–4 предложения с конструктивной обратной связью), "score" (number, от 1 до 10), "tips" (array of 2–3 строк с советами по улучшению ответа).',
      },
      {
        role: 'user',
        content: `Вакансия: ${data.vacancyTitle}\n\nВопрос: ${data.question}\n\nОтвет кандидата: ${data.answer.slice(0, 2000)}`,
      },
    ],
    max_tokens: 600,
  });

  try {
    const parsed = JSON.parse(resp.choices[0].message.content ?? '{}') as Partial<InterviewFeedback>;
    return {
      feedback: parsed.feedback ?? 'Ответ принят.',
      score: typeof parsed.score === 'number' ? Math.max(1, Math.min(10, parsed.score)) : 5,
      tips: Array.isArray(parsed.tips) ? (parsed.tips as string[]).slice(0, 3) : [],
    };
  } catch {
    return { feedback: 'Ответ принят.', score: 5, tips: [] };
  }
}

// ── Vacancy description ────────────────────────────────────────────────────────

export async function generateVacancyDescription(data: {
  title: string;
  requirements?: string;
  conditions?: string;
}): Promise<string> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'system',
        content:
          'Ты — опытный HR-менеджер. Напиши профессиональное описание вакансии на русском языке. Структурируй текст с разделами: **О компании**, **Задачи**, **Требования**, **Условия**. Текст должен быть конкретным, лаконичным и привлекательным для кандидатов. Без шаблонных вводных.',
      },
      {
        role: 'user',
        content: [
          `Вакансия: ${data.title}`,
          data.requirements ? `Требования: ${data.requirements}` : '',
          data.conditions ? `Условия: ${data.conditions}` : '',
        ].filter(Boolean).join('\n'),
      },
    ],
    max_tokens: 800,
  });
  return (resp.choices[0].message.content ?? '').trim();
}

// ── Match percent ──────────────────────────────────────────────────────────────

export interface MatchResult {
  percent: number;
  explanation: string;
}

export async function calculateMatchPercent(data: {
  resumeTitle: string;
  resumeSkills: string[];
  resumeExperience: string;
  vacancyTitle: string;
  vacancyDescription: string;
}): Promise<MatchResult> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'Ты — HR-аналитик. Оцени соответствие резюме вакансии. Верни JSON с полями: "percent" (целое число от 0 до 100), "explanation" (строка, 1–2 предложения на русском с конкретным объяснением оценки).',
      },
      {
        role: 'user',
        content: [
          `Резюме:`,
          `Должность: ${data.resumeTitle}`,
          `Навыки: ${data.resumeSkills.join(', ')}`,
          `Опыт: ${data.resumeExperience.slice(0, 800)}`,
          ``,
          `Вакансия:`,
          `Название: ${data.vacancyTitle}`,
          `Описание: ${data.vacancyDescription.slice(0, 800)}`,
        ].join('\n'),
      },
    ],
    max_tokens: 300,
  });

  try {
    const parsed = JSON.parse(resp.choices[0].message.content ?? '{}') as {
      percent?: number;
      explanation?: string;
    };
    return {
      percent: typeof parsed.percent === 'number'
        ? Math.max(0, Math.min(100, Math.round(parsed.percent)))
        : 50,
      explanation: parsed.explanation ?? '',
    };
  } catch {
    return { percent: 50, explanation: '' };
  }
}

// ── Simple keyword score (no AI, for bulk operations) ─────────────────────────

export function keywordScore(resumeText: string, vacancyText: string): number {
  const normalize = (s: string) =>
    s.toLowerCase().replace(/[^\wа-яёa-z0-9 ]/gi, ' ').split(/\s+/).filter((w) => w.length > 2);

  const resumeSet = new Set(normalize(resumeText));
  const vacancyWords = normalize(vacancyText);

  if (resumeSet.size === 0 || vacancyWords.length === 0) return 30;

  const matches = vacancyWords.filter((w) => resumeSet.has(w)).length;
  const raw = Math.round((matches / Math.max(vacancyWords.length, 1)) * 100);
  return Math.min(90, Math.max(10, raw));
}

// ── Cover letter ───────────────────────────────────────────────────────────────

export async function generateCoverLetter(data: {
  seekerName: string;
  resumeTitle: string;
  resumeSkills: string[];
  resumeSummary: string;
  vacancyTitle: string;
  companyName: string;
}): Promise<string> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'system',
        content:
          'Ты — карьерный консультант. Напиши персонализированное сопроводительное письмо на русском языке. 3–4 абзаца: краткое введение, ключевые достижения/навыки, мотивация работать в компании, заключение. Конкретно, без клише.',
      },
      {
        role: 'user',
        content: [
          `Кандидат: ${data.seekerName}`,
          `Желаемая должность: ${data.resumeTitle}`,
          `Навыки: ${data.resumeSkills.slice(0, 10).join(', ')}`,
          data.resumeSummary ? `О себе: ${data.resumeSummary.slice(0, 400)}` : '',
          ``,
          `Вакансия: ${data.vacancyTitle}`,
          `Компания: ${data.companyName}`,
        ].filter(Boolean).join('\n'),
      },
    ],
    max_tokens: 600,
  });
  return (resp.choices[0].message.content ?? '').trim();
}

// ── Salary estimate ────────────────────────────────────────────────────────────

export interface SalaryEstimate {
  min: number;
  max: number;
  currency: string;
  explanation: string;
}

export async function estimateSalary(data: {
  title: string;
  skills: string[];
  experience: string;
}): Promise<SalaryEstimate> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'Ты — эксперт по рынку труда в Узбекистане (Ташкент). Оцени рыночную зарплату специалиста. Верни JSON: "min" (число, в сумах), "max" (число, в сумах), "currency" ("UZS"), "explanation" (строка, 1–2 предложения). Суммы реалистичные для рынка Ташкента 2024–2025.',
      },
      {
        role: 'user',
        content: [
          `Должность: ${data.title}`,
          `Навыки: ${data.skills.slice(0, 10).join(', ')}`,
          `Опыт: ${data.experience.slice(0, 500)}`,
        ].join('\n'),
      },
    ],
    max_tokens: 300,
  });

  try {
    const parsed = JSON.parse(resp.choices[0].message.content ?? '{}') as Partial<SalaryEstimate>;
    return {
      min: typeof parsed.min === 'number' ? parsed.min : 3_000_000,
      max: typeof parsed.max === 'number' ? parsed.max : 8_000_000,
      currency: 'UZS',
      explanation: parsed.explanation ?? '',
    };
  } catch {
    return { min: 3_000_000, max: 8_000_000, currency: 'UZS', explanation: '' };
  }
}

// ── Resume score ───────────────────────────────────────────────────────────────

export interface ResumeScore {
  score: number;
  strengths: string[];
  improvements: string[];
  summary: string;
}

export async function scoreResume(content: ResumeContent): Promise<ResumeScore> {
  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'Ты — эксперт по оценке резюме. Оцени резюме по шкале от 0 до 100. Верни JSON: "score" (число), "strengths" (массив 2–3 строки — сильные стороны), "improvements" (массив 2–3 строки — что улучшить), "summary" (строка, 1–2 предложения с общей оценкой). Отвечай только на русском.',
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
    const parsed = JSON.parse(resp.choices[0].message.content ?? '{}') as Partial<ResumeScore>;
    return {
      score: typeof parsed.score === 'number' ? Math.max(0, Math.min(100, Math.round(parsed.score))) : 60,
      strengths: Array.isArray(parsed.strengths) ? (parsed.strengths as string[]).slice(0, 3) : [],
      improvements: Array.isArray(parsed.improvements) ? (parsed.improvements as string[]).slice(0, 3) : [],
      summary: parsed.summary ?? '',
    };
  } catch {
    return { score: 60, strengths: [], improvements: [], summary: '' };
  }
}

// ── Transcription ──────────────────────────────────────────────────────────────

export async function transcribeAudio(buffer: Buffer, mimetype: string): Promise<string> {
  const ext = mimetype.includes('webm') ? 'webm'
    : mimetype.includes('ogg')  ? 'ogg'
    : mimetype.includes('mp4')  ? 'mp4'
    : mimetype.includes('wav')  ? 'wav'
    : 'webm';

  const audioFile = await toFile(buffer, `recording.${ext}`, { type: mimetype });

  const transcription = await groq.audio.transcriptions.create({
    file:  audioFile,
    model: 'whisper-large-v3',
    language: 'ru',
  });
  return transcription.text;
}
