import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

async function getSeeker(userId: string) {
  return prisma.seekerProfile.findUnique({ where: { userId } });
}

// GET /api/subscriptions
export async function getSubscriptions(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { ok(res, { subscriptions: [] }); return; }

    const subscriptions = await prisma.vacancySubscription.findMany({
      where: { seekerId: seeker.id },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { subscriptions });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/subscriptions
export async function createSubscription(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { fail(res, 'Создайте профиль соискателя', 400); return; }

    const { query, city, salaryMin, employmentType } = req.body as {
      query?: string;
      city?: string;
      salaryMin?: number;
      employmentType?: string;
    };

    if (!query && !city && !employmentType) {
      fail(res, 'Укажите хотя бы один критерий поиска'); return;
    }

    const subscription = await prisma.vacancySubscription.create({
      data: {
        seekerId: seeker.id,
        query: query ?? null,
        city: city ?? null,
        salaryMin: salaryMin ?? null,
        employmentType: employmentType ?? null,
      },
    });

    ok(res, { subscription }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// DELETE /api/subscriptions/:id
export async function deleteSubscription(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params as { id: string };

    const seeker = await getSeeker(req.user!.userId);
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const existing = await prisma.vacancySubscription.findFirst({
      where: { id, seekerId: seeker.id },
    });
    if (!existing) { fail(res, 'Подписка не найдена', 404); return; }

    await prisma.vacancySubscription.delete({ where: { id } });
    ok(res, { deleted: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
