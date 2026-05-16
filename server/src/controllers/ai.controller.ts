import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import {
  matchPercent,
  matchVacancies,
  matchResumes,
  generateCoverLetter,
  estimateSalary,
} from '../services/ai/match.service';
import {
  generateInterviewQuestions,
  evaluateInterviewAnswer,
} from '../services/ai/groq.service';

// ── Helpers ───────────────────────────────────────────────────────────────────

type ResumeRow = Awaited<ReturnType<typeof prisma.resume.findUniqueOrThrow>>;
type VacancyRow = Awaited<ReturnType<typeof prisma.vacancy.findUniqueOrThrow>>;

function resumeToText(r: ResumeRow): string {
  const c = (typeof r.content === 'object' && r.content !== null && !Array.isArray(r.content))
    ? r.content as Record<string, unknown>
    : {};
  return [
    `Должность: ${r.title}`,
    c['summary']    ? `О себе: ${c['summary']}`         : '',
    c['experience'] ? `Опыт: ${c['experience']}`         : '',
    c['education']  ? `Образование: ${c['education']}`   : '',
    r.skills.length ? `Навыки: ${r.skills.join(', ')}`   : '',
    c['languages']  ? `Языки: ${c['languages']}`         : '',
    r.experience    ? `Стаж: ${r.experience}`             : '',
    c['rawText']    ? `Текст резюме: ${c['rawText']}`    : '',
  ].filter(Boolean).join('\n');
}

function vacancyToText(v: VacancyRow): string {
  return [
    `Должность: ${v.title}`,
    `Описание: ${v.description}`,
    v.employmentType ? `Тип занятости: ${v.employmentType}` : '',
    v.experience     ? `Требуемый опыт: ${v.experience}`     : '',
    v.city           ? `Город: ${v.city}`                    : '',
  ].filter(Boolean).join('\n');
}

// ── POST /api/ai/interview-prep ───────────────────────────────────────────────

export async function aiInterviewPrep(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyTitle, vacancyDescription, vacancyId } = req.body as {
    vacancyTitle?: string;
    vacancyDescription?: string;
    vacancyId?: string;
  };

  let title = vacancyTitle?.trim() ?? '';
  let description = vacancyDescription?.trim() ?? '';

  if (vacancyId && !title) {
    try {
      const vacancy = await prisma.vacancy.findUnique({
        where: { id: vacancyId },
        select: { title: true, description: true },
      });
      if (vacancy) {
        title = vacancy.title;
        description = vacancy.description;
      }
    } catch {
      // fall through
    }
  }

  if (!title) { fail(res, 'vacancyTitle обязателен'); return; }

  try {
    const questions = await generateInterviewQuestions({ vacancyTitle: title, vacancyDescription: description || undefined });
    ok(res, { questions, vacancyTitle: title });
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/interview-feedback ──────────────────────────────────────────

export async function aiInterviewFeedback(req: AuthRequest, res: Response): Promise<void> {
  const { question, answer, vacancyTitle } = req.body as {
    question: string;
    answer: string;
    vacancyTitle: string;
  };

  if (!question || !answer || !vacancyTitle) {
    fail(res, 'question, answer и vacancyTitle обязательны'); return;
  }
  if (answer.trim().length < 5) {
    fail(res, 'Ответ слишком короткий'); return;
  }

  try {
    const result = await evaluateInterviewAnswer({ question, answer, vacancyTitle });
    ok(res, result);
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/match-percent ────────────────────────────────────────────────

export async function aiMatchPercent(req: AuthRequest, res: Response): Promise<void> {
  const { resumeId, vacancyId } = req.body as { resumeId?: string; vacancyId?: string };
  if (!resumeId || !vacancyId) { fail(res, 'resumeId и vacancyId обязательны'); return; }

  try {
    const [resume, vacancy] = await Promise.all([
      prisma.resume.findUnique({ where: { id: resumeId } }),
      prisma.vacancy.findUnique({ where: { id: vacancyId } }),
    ]);
    if (!resume)  { fail(res, 'Резюме не найдено'); return; }
    if (!vacancy) { fail(res, 'Вакансия не найдена'); return; }

    const result = await matchPercent(resumeToText(resume), vacancyToText(vacancy));
    ok(res, result);
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/match-vacancies ──────────────────────────────────────────────

export async function aiMatchVacancies(req: AuthRequest, res: Response): Promise<void> {
  const { resumeId } = req.body as { resumeId?: string };
  if (!resumeId) { fail(res, 'resumeId обязателен'); return; }

  try {
    const resume = await prisma.resume.findUnique({ where: { id: resumeId } });
    if (!resume) { fail(res, 'Резюме не найдено'); return; }

    const vacancies = await prisma.vacancy.findMany({
      where: { isActive: true },
      include: { employer: { select: { companyName: true, logoUrl: true, city: true } } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    const matches = await matchVacancies(
      resumeToText(resume),
      vacancies.map(v => ({
        id:             v.id,
        title:          v.title,
        description:    v.description,
        employmentType: v.employmentType,
        experience:     v.experience,
      })),
    );

    const vacancyMap = new Map(vacancies.map(v => [v.id, v]));
    const enriched = matches
      .map(m => ({ ...m, vacancy: vacancyMap.get(m.vacancyId) ?? null }))
      .filter(m => m.vacancy !== null);

    ok(res, { matches: enriched });
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/match-resumes ────────────────────────────────────────────────

export async function aiMatchResumes(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyId } = req.body as { vacancyId?: string };
  if (!vacancyId) { fail(res, 'vacancyId обязателен'); return; }

  try {
    const vacancy = await prisma.vacancy.findUnique({ where: { id: vacancyId } });
    if (!vacancy) { fail(res, 'Вакансия не найдена'); return; }

    const resumes = await prisma.resume.findMany({
      include: {
        seeker: {
          select: { firstName: true, lastName: true, city: true, photoUrl: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take: 20,
    });

    const matches = await matchResumes(
      vacancyToText(vacancy),
      resumes.map(r => ({
        id:         r.id,
        title:      r.title,
        skills:     r.skills,
        experience: r.experience,
      })),
    );

    const resumeMap = new Map(resumes.map(r => [r.id, r]));
    const enriched = matches
      .map(m => ({ ...m, resume: resumeMap.get(m.resumeId) ?? null }))
      .filter(m => m.resume !== null);

    ok(res, { matches: enriched });
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/cover-letter ─────────────────────────────────────────────────

export async function aiCoverLetter(req: AuthRequest, res: Response): Promise<void> {
  const { resumeId, vacancyId } = req.body as { resumeId?: string; vacancyId?: string };
  if (!resumeId || !vacancyId) { fail(res, 'resumeId и vacancyId обязательны'); return; }

  try {
    const [resume, vacancy] = await Promise.all([
      prisma.resume.findUnique({ where: { id: resumeId } }),
      prisma.vacancy.findUnique({ where: { id: vacancyId } }),
    ]);
    if (!resume)  { fail(res, 'Резюме не найдено'); return; }
    if (!vacancy) { fail(res, 'Вакансия не найдена'); return; }

    const coverLetter = await generateCoverLetter(resumeToText(resume), vacancyToText(vacancy));
    ok(res, { coverLetter });
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}

// ── POST /api/ai/salary-estimate ──────────────────────────────────────────────

export async function aiSalaryEstimate(req: AuthRequest, res: Response): Promise<void> {
  const { resumeId } = req.body as { resumeId?: string };
  if (!resumeId) { fail(res, 'resumeId обязателен'); return; }

  try {
    const resume = await prisma.resume.findUnique({ where: { id: resumeId } });
    if (!resume) { fail(res, 'Резюме не найдено'); return; }

    const estimate = await estimateSalary(resumeToText(resume));
    ok(res, estimate);
  } catch (e) {
    fail(res, `Ошибка ИИ: ${e instanceof Error ? e.message : 'неизвестная ошибка'}`);
  }
}
