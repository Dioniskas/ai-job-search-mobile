import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

async function getSeeker(userId: string) {
  return prisma.seekerProfile.findUnique({ where: { userId } });
}

// GET /api/saved
export async function getSavedVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { ok(res, { saved: [] }); return; }

    const saved = await prisma.savedVacancy.findMany({
      where: { seekerId: seeker.id },
      include: {
        vacancy: {
          include: {
            employer: { select: { companyName: true, logoUrl: true, city: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { saved: saved.map((s) => s.vacancy) });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/saved/:vacancyId
export async function saveVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { vacancyId } = req.params as { vacancyId: string };

    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { fail(res, 'Создайте профиль соискателя', 400); return; }

    const vacancy = await prisma.vacancy.findUnique({ where: { id: vacancyId } });
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    await prisma.savedVacancy.upsert({
      where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
      create: { seekerId: seeker.id, vacancyId },
      update: {},
    });

    ok(res, { saved: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// DELETE /api/saved/:vacancyId
export async function unsaveVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { vacancyId } = req.params as { vacancyId: string };

    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    await prisma.savedVacancy.deleteMany({
      where: { seekerId: seeker.id, vacancyId },
    });

    ok(res, { saved: false });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// GET /api/saved/:vacancyId/check
export async function checkSavedVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { vacancyId } = req.params as { vacancyId: string };

    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { ok(res, { isSaved: false }); return; }

    const record = await prisma.savedVacancy.findFirst({
      where: { seekerId: seeker.id, vacancyId },
    });

    ok(res, { isSaved: record !== null });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
