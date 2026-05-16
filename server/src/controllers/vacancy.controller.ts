import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { generateVacancyDescription } from '../services/ai/groq.service';
import prisma from '../lib/prisma';

export async function listVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { search, city, salaryMin, salaryMax, employmentType, experience, page: pageStr, limit: limitStr } = req.query as Record<string, string | undefined>;

    const page  = Math.max(1, parseInt(pageStr  ?? '1',  10));
    const limit = Math.min(50, Math.max(1, parseInt(limitStr ?? '20', 10)));
    const skip  = (page - 1) * limit;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const where: Record<string, any> = { isActive: true, isModerated: true };

    if (search)          where['title']          = { contains: search,       mode: 'insensitive' };
    if (city)            where['city']           = { contains: city,         mode: 'insensitive' };
    if (salaryMin)       where['salaryMax']      = { gte: Number(salaryMin) };
    if (salaryMax)       where['salaryMin']      = { lte: Number(salaryMax) };
    if (employmentType)  where['employmentType'] = employmentType;
    if (experience)      where['experience']     = experience;

    const [vacancies, total] = await Promise.all([
      prisma.vacancy.findMany({
        where,
        include: { employer: { select: { companyName: true, logoUrl: true, city: true } } },
        orderBy: [{ boostedUntil: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.vacancy.count({ where }),
    ]);

    ok(res, { data: vacancies, total, page, totalPages: Math.ceil(total / limit) });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getMapVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const vacancies = await prisma.vacancy.findMany({
      where: { isActive: true, isModerated: true, lat: { not: null }, lng: { not: null } },
      select: {
        id: true, title: true, city: true,
        salaryMin: true, salaryMax: true,
        lat: true, lng: true,
        employer: { select: { companyName: true } },
      },
      take: 200,
    });
    ok(res, { vacancies });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getEmployerVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { ok(res, { vacancies: [] }); return; }

    const vacancies = await prisma.vacancy.findMany({
      where: { employerId: employer.id },
      include: { _count: { select: { applications: true } } },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { vacancies });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function aiGenerateDescription(req: AuthRequest, res: Response): Promise<void> {
  const { title, requirements, conditions } = req.body as {
    title?: string; requirements?: string; conditions?: string;
  };
  if (!title) { fail(res, 'title is required'); return; }

  try {
    const description = await generateVacancyDescription({ title, requirements, conditions });
    ok(res, { description });
  } catch (e) {
    fail(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const vacancy = await prisma.vacancy.findUnique({
      where: { id },
      include: { employer: true },
    });
    if (!vacancy || !vacancy.isModerated) { fail(res, 'Vacancy not found'); return; }

    await prisma.vacancy.update({ where: { id }, data: { viewCount: { increment: 1 } } });

    const similar = await prisma.vacancy.findMany({
      where: {
        isActive: true,
        isModerated: true,
        id: { not: id },
        OR: [
          ...(vacancy.employmentType ? [{ employmentType: vacancy.employmentType }] : []),
          ...(vacancy.city           ? [{ city: vacancy.city }]                     : []),
        ],
      },
      include: { employer: { select: { companyName: true, logoUrl: true } } },
      take: 5,
    });

    ok(res, { vacancy, similar });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function createVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { title, description, salaryMin, salaryMax, city, lat, lng, employmentType, experience } = req.body as Record<string, string | undefined>;

  if (!title || !description) { fail(res, 'title and description are required'); return; }

  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { fail(res, 'Employer profile not found. Please complete your profile first.'); return; }

    const vacancy = await prisma.vacancy.create({
      data: {
        employerId:     employer.id,
        title,
        description,
        salaryMin:      salaryMin      ? parseInt(salaryMin)      : null,
        salaryMax:      salaryMax      ? parseInt(salaryMax)      : null,
        city:           city           ?? null,
        lat:            lat            ? parseFloat(lat)          : null,
        lng:            lng            ? parseFloat(lng)          : null,
        employmentType: employmentType ?? null,
        experience:     experience     ?? null,
      },
    });

    ok(res, { vacancy });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function updateVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  const { isActive, title, description, salaryMin, salaryMax, city, employmentType, experience } = req.body as Record<string, any>;

  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { fail(res, 'Employer profile not found'); return; }

    const existing = await prisma.vacancy.findUnique({ where: { id } });
    if (!existing || existing.employerId !== employer.id) { fail(res, 'Vacancy not found or access denied'); return; }

    const vacancy = await prisma.vacancy.update({
      where: { id },
      data: {
        ...(isActive      !== undefined ? { isActive }                             : {}),
        ...(title         !== undefined ? { title }                                : {}),
        ...(description   !== undefined ? { description }                          : {}),
        ...(salaryMin     !== undefined ? { salaryMin:      Number(salaryMin) }    : {}),
        ...(salaryMax     !== undefined ? { salaryMax:      Number(salaryMax) }    : {}),
        ...(city          !== undefined ? { city }                                 : {}),
        ...(employmentType !== undefined ? { employmentType }                      : {}),
        ...(experience    !== undefined ? { experience }                           : {}),
      },
    });

    ok(res, { vacancy });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function deleteVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { fail(res, 'Employer profile not found'); return; }

    const existing = await prisma.vacancy.findUnique({ where: { id } });
    if (!existing || existing.employerId !== employer.id) { fail(res, 'Vacancy not found or access denied'); return; }

    await prisma.vacancy.delete({ where: { id } });
    ok(res, { deleted: true });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function applyToVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id: vacancyId } = req.params;
  const { resumeId, coverLetter } = req.body as { resumeId?: string; coverLetter?: string };

  if (!resumeId) { fail(res, 'resumeId is required'); return; }

  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { fail(res, 'Seeker profile not found. Please complete your profile first.'); return; }

    const vacancy = await prisma.vacancy.findUnique({ where: { id: vacancyId } });
    if (!vacancy) { fail(res, 'Vacancy not found'); return; }

    const application = await prisma.application.create({
      data: {
        resumeId,
        vacancyId,
        seekerId:    seeker.id,
        employerId:  vacancy.employerId,
        coverLetter: coverLetter ?? null,
      },
    });

    // Notify employer
    const employer = await prisma.employer.findUnique({
      where: { id: vacancy.employerId },
      select: { userId: true },
    });
    if (employer) {
      const name = [seeker.firstName, seeker.lastName].filter(Boolean).join(' ') || 'Соискатель';
      await prisma.notification.create({
        data: {
          userId: employer.userId,
          type:   'NEW_APPLICATION',
          text:   `${name} откликнулся на вакансию «${vacancy.title}»`,
        },
      });
    }

    ok(res, { application });
  } catch (e: any) {
    if (e?.code === 'P2002') { fail(res, 'Вы уже откликались на эту вакансию'); return; }
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
