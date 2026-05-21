import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import { generateVacancyDescription } from '../services/ai/groq.service';

// ── List vacancies (public-ish, requires auth) ─────────────────────────────────
export async function listVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { search, city, salaryMin, salaryMax, employmentType, experience } =
      req.query as Record<string, string | undefined>;

    const where: Record<string, unknown> = { isActive: true };

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
      if (salaryMin) (where.salaryMin as Record<string, number>).gte = parseInt(salaryMin, 10);
      if (salaryMax) (where.salaryMin as Record<string, number>).lte = parseInt(salaryMax, 10);
    }

    const now = new Date();
    const vacancies = await prisma.vacancy.findMany({
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

    ok(res, { vacancies: result });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Map vacancies (with lat/lng only) ──────────────────────────────────────────
export async function getMapVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const vacancies = await prisma.vacancy.findMany({
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
    ok(res, { vacancies });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Get employer's own vacancies ────────────────────────────────────────────────
export async function getEmployerVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { ok(res, { vacancies: [] }); return; }

    const now = new Date();
    const vacancies = await prisma.vacancy.findMany({
      where: { employerId: employer.id },
      orderBy: { createdAt: 'desc' },
    });

    const result = vacancies.map((v) => ({
      ...v,
      isBoosted: v.boostedUntil !== null && v.boostedUntil > now,
    }));

    ok(res, { vacancies: result });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Get single vacancy ─────────────────────────────────────────────────────────
export async function getVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params as { id: string };

    const vacancy = await prisma.vacancy.findUnique({
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

    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    // Increment view count
    await prisma.vacancy.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
    }).catch(() => null);

    // Similar vacancies (same city or employer, different id)
    const similar = await prisma.vacancy.findMany({
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

    ok(res, { vacancy, similar });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Create vacancy ─────────────────────────────────────────────────────────────
export async function createVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { fail(res, 'Сначала создайте профиль компании', 400); return; }

    const {
      title, description, salaryMin, salaryMax, city, lat, lng,
      employmentType, experience,
    } = req.body as {
      title: string;
      description: string;
      salaryMin?: number;
      salaryMax?: number;
      city?: string;
      lat?: number;
      lng?: number;
      employmentType?: string;
      experience?: string;
    };

    if (!title || !description) {
      fail(res, 'title и description обязательны'); return;
    }

    const vacancy = await prisma.vacancy.create({
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

    ok(res, { vacancy }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Update vacancy ─────────────────────────────────────────────────────────────
export async function updateVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params as { id: string };

    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { fail(res, 'Профиль работодателя не найден', 404); return; }

    const existing = await prisma.vacancy.findFirst({
      where: { id, employerId: employer.id },
    });
    if (!existing) { fail(res, 'Вакансия не найдена', 404); return; }

    const {
      title, description, salaryMin, salaryMax, city, lat, lng,
      employmentType, experience, isActive,
    } = req.body as {
      title?: string;
      description?: string;
      salaryMin?: number | null;
      salaryMax?: number | null;
      city?: string | null;
      lat?: number | null;
      lng?: number | null;
      employmentType?: string | null;
      experience?: string | null;
      isActive?: boolean;
    };

    const vacancy = await prisma.vacancy.update({
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

    ok(res, { vacancy });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Delete vacancy ─────────────────────────────────────────────────────────────
export async function deleteVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params as { id: string };

    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { fail(res, 'Профиль не найден', 404); return; }

    const existing = await prisma.vacancy.findFirst({
      where: { id, employerId: employer.id },
    });
    if (!existing) { fail(res, 'Вакансия не найдена', 404); return; }

    await prisma.vacancy.delete({ where: { id } });
    ok(res, { deleted: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── AI vacancy description ─────────────────────────────────────────────────────
export async function aiVacancyDescription(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { title, requirements, conditions } = req.body as {
      title: string;
      requirements?: string;
      conditions?: string;
    };

    if (!title) { fail(res, 'title обязателен'); return; }

    const description = await generateVacancyDescription({ title, requirements, conditions });
    ok(res, { description });
  } catch (e) {
    fail(res, `Ошибка AI: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Apply to vacancy ───────────────────────────────────────────────────────────
export async function applyToVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id: vacancyId } = req.params as { id: string };
    const { resumeId, coverLetter } = req.body as {
      resumeId: string;
      coverLetter?: string;
    };

    if (!resumeId) { fail(res, 'resumeId обязателен'); return; }

    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { fail(res, 'Создайте профиль соискателя', 400); return; }

    const vacancy = await prisma.vacancy.findUnique({
      where: { id: vacancyId },
      include: { employer: { select: { id: true, userId: true } } },
    });
    if (!vacancy || !vacancy.isActive) {
      fail(res, 'Вакансия не найдена или закрыта', 404); return;
    }

    const resume = await prisma.resume.findFirst({
      where: { id: resumeId, seekerId: seeker.id },
    });
    if (!resume) { fail(res, 'Резюме не найдено', 404); return; }

    // Check if already applied
    const existing = await prisma.application.findFirst({
      where: { resumeId, vacancyId },
    });
    if (existing) { fail(res, 'Вы уже откликались на эту вакансию', 409); return; }

    const application = await prisma.application.create({
      data: {
        resumeId,
        vacancyId,
        seekerId: seeker.id,
        employerId: vacancy.employer.id,
        coverLetter: coverLetter ?? null,
      },
    });

    // Notify employer
    await prisma.notification.create({
      data: {
        userId: vacancy.employer.userId,
        type: 'NEW_APPLICATION',
        text: `Новый отклик на вакансию "${vacancy.title}"`,
        link: `/applications/${application.id}`,
      },
    }).catch(() => null);

    ok(res, { application }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
