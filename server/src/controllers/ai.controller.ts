import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import {
  generateRejection,
  generateInterviewQuestions,
  evaluateInterviewAnswer,
  calculateMatchPercent,
  keywordScore,
  generateCoverLetter,
  estimateSalary,
} from '../services/ai/groq.service';

export async function generateRejectionReason(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId, role } = req.user!;

    if (role !== 'EMPLOYER') { fail(res, 'Доступ запрещён', 403); return; }

    const { applicationId } = req.body as { applicationId: string };
    if (!applicationId) { fail(res, 'applicationId обязателен'); return; }

    const application = await prisma.application.findUnique({
      where: { id: applicationId },
      include: {
        employer: { select: { userId: true, companyName: true } },
        seeker: { select: { firstName: true, lastName: true } },
        vacancy: { select: { title: true } },
      },
    });

    if (!application) { fail(res, 'Отклик не найден', 404); return; }
    if (application.employer.userId !== userId) { fail(res, 'Доступ запрещён', 403); return; }

    const text = await generateRejection({
      companyName: application.employer.companyName,
      seekerName: `${application.seeker.firstName} ${application.seeker.lastName}`,
      vacancyTitle: application.vacancy.title,
    });

    ok(res, { text });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function interviewPrep(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { vacancyTitle, vacancyDescription, vacancyId } = req.body as {
      vacancyTitle?: string;
      vacancyDescription?: string;
      vacancyId?: string;
    };

    let title = vacancyTitle?.trim() ?? '';
    let description = vacancyDescription?.trim() ?? '';

    if (vacancyId && !title) {
      const vacancy = await prisma.vacancy.findUnique({
        where: { id: vacancyId },
        select: { title: true, description: true },
      });
      if (vacancy) {
        title = vacancy.title;
        description = vacancy.description;
      }
    }

    if (!title) { fail(res, 'vacancyTitle обязателен'); return; }

    const questions = await generateInterviewQuestions({ vacancyTitle: title, vacancyDescription: description || undefined });

    ok(res, { questions, vacancyTitle: title });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function interviewFeedback(req: AuthRequest, res: Response): Promise<void> {
  try {
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

    const result = await evaluateInterviewAnswer({ question, answer, vacancyTitle });

    ok(res, result);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Match percent ──────────────────────────────────────────────────────────────

export async function matchPercent(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { resumeId, vacancyId } = req.body as { resumeId: string; vacancyId: string };

    if (!resumeId || !vacancyId) {
      fail(res, 'resumeId и vacancyId обязательны'); return;
    }

    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { fail(res, 'Профиль соискателя не найден', 404); return; }

    const [resume, vacancy] = await Promise.all([
      prisma.resume.findFirst({
        where: { id: resumeId, seekerId: seeker.id },
      }),
      prisma.vacancy.findUnique({ where: { id: vacancyId } }),
    ]);

    if (!resume) { fail(res, 'Резюме не найдено', 404); return; }
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    const content = resume.content as Record<string, unknown>;

    const result = await calculateMatchPercent({
      resumeTitle: resume.title,
      resumeSkills: resume.skills,
      resumeExperience: resume.experience ?? '',
      vacancyTitle: vacancy.title,
      vacancyDescription: vacancy.description,
    });

    // Update matchPercent in application if exists
    await prisma.application.updateMany({
      where: { resumeId, vacancyId, seekerId: seeker.id },
      data: { matchPercent: result.percent },
    }).catch(() => null);

    ok(res, { percent: result.percent, explanation: result.explanation });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Match vacancies for a resume ───────────────────────────────────────────────

export async function matchVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { resumeId } = req.body as { resumeId: string };
    if (!resumeId) { fail(res, 'resumeId обязателен'); return; }

    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const resume = await prisma.resume.findFirst({
      where: { id: resumeId, seekerId: seeker.id },
    });
    if (!resume) { fail(res, 'Резюме не найдено', 404); return; }

    const vacancies = await prisma.vacancy.findMany({
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
        const percent = keywordScore(resumeText, vacancyText);
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

    ok(res, { matches: scored });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Match resumes for a vacancy ────────────────────────────────────────────────

export async function matchResumes(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { vacancyId } = req.body as { vacancyId: string };
    if (!vacancyId) { fail(res, 'vacancyId обязателен'); return; }

    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { fail(res, 'Профиль не найден', 404); return; }

    const vacancy = await prisma.vacancy.findFirst({
      where: { id: vacancyId, employerId: employer.id },
    });
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    const resumes = await prisma.resume.findMany({
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
        const percent = keywordScore(resumeText, vacancyText);
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

    ok(res, { matches: scored });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Cover letter ───────────────────────────────────────────────────────────────

export async function coverLetter(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { resumeId, vacancyId } = req.body as { resumeId: string; vacancyId: string };
    if (!resumeId || !vacancyId) {
      fail(res, 'resumeId и vacancyId обязательны'); return;
    }

    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const [resume, vacancy] = await Promise.all([
      prisma.resume.findFirst({ where: { id: resumeId, seekerId: seeker.id } }),
      prisma.vacancy.findUnique({
        where: { id: vacancyId },
        include: { employer: { select: { companyName: true } } },
      }),
    ]);

    if (!resume) { fail(res, 'Резюме не найдено', 404); return; }
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    const content = resume.content as Record<string, unknown>;

    const letter = await generateCoverLetter({
      seekerName: `${seeker.firstName} ${seeker.lastName}`,
      resumeTitle: resume.title,
      resumeSkills: resume.skills,
      resumeSummary: (content['summary'] as string) ?? '',
      vacancyTitle: vacancy.title,
      companyName: vacancy.employer.companyName,
    });

    ok(res, { coverLetter: letter });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Salary estimate ────────────────────────────────────────────────────────────

export async function salaryEstimate(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { resumeId } = req.body as { resumeId: string };
    if (!resumeId) { fail(res, 'resumeId обязателен'); return; }

    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const resume = await prisma.resume.findFirst({
      where: { id: resumeId, seekerId: seeker.id },
    });
    if (!resume) { fail(res, 'Резюме не найдено', 404); return; }

    const estimate = await estimateSalary({
      title: resume.title,
      skills: resume.skills,
      experience: resume.experience ?? '',
    });

    ok(res, estimate);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
