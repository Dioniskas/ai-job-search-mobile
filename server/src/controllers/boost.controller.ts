import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

const VALID_DAYS = [7, 30, 90];

function boostUntil(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

export async function boostResume(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;
    const { days } = req.body as { days: number };

    if (!VALID_DAYS.includes(days)) {
      fail(res, `days должен быть одним из: ${VALID_DAYS.join(', ')}`); return;
    }

    const seeker = await prisma.seekerProfile.findUnique({ where: { userId } });
    if (!seeker) { fail(res, 'Профиль соискателя не найден', 404); return; }

    const until = boostUntil(days);
    const updated = await prisma.seekerProfile.update({
      where: { id: seeker.id },
      data: { boostedUntil: until },
      select: { boostedUntil: true },
    });

    ok(res, {
      boostedUntil: updated.boostedUntil,
      days,
      message: `Резюме поднято в поиске на ${days} дней`,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function boostVacancy(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;
    const { vacancyId, days } = req.body as { vacancyId: string; days: number };

    if (!vacancyId) { fail(res, 'vacancyId обязателен'); return; }
    if (!VALID_DAYS.includes(days)) {
      fail(res, `days должен быть одним из: ${VALID_DAYS.join(', ')}`); return;
    }

    const employer = await prisma.employer.findUnique({ where: { userId } });
    if (!employer) { fail(res, 'Профиль работодателя не найден', 404); return; }

    const vacancy = await prisma.vacancy.findUnique({ where: { id: vacancyId } });
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }
    if (vacancy.employerId !== employer.id) { fail(res, 'Нет доступа к этой вакансии', 403); return; }

    const until = boostUntil(days);
    const updated = await prisma.vacancy.update({
      where: { id: vacancyId },
      data: { boostedUntil: until },
      select: { id: true, title: true, boostedUntil: true },
    });

    ok(res, {
      vacancy: updated,
      days,
      message: `Вакансия "${updated.title}" продвинута на ${days} дней`,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getBoostStatus(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId, role } = req.user!;
    const now = new Date();

    if (role === 'SEEKER') {
      const seeker = await prisma.seekerProfile.findUnique({
        where: { userId },
        select: { boostedUntil: true },
      });
      const boostedUntil = seeker?.boostedUntil ?? null;
      ok(res, {
        isBoosted: boostedUntil !== null && boostedUntil > now,
        boostedUntil,
      });
    } else {
      const employer = await prisma.employer.findUnique({ where: { userId } });
      if (!employer) { fail(res, 'Профиль не найден', 404); return; }

      const vacancies = await prisma.vacancy.findMany({
        where: { employerId: employer.id, isActive: true },
        select: { id: true, title: true, boostedUntil: true },
        orderBy: { createdAt: 'desc' },
      });

      ok(res, {
        vacancies: vacancies.map((v) => ({
          ...v,
          isBoosted: v.boostedUntil !== null && v.boostedUntil > now,
        })),
      });
    }
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
