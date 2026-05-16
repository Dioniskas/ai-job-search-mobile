import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

// GET /api/subscriptions
export async function getSubscriptions(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { ok(res, { subscriptions: [] }); return; }

    const subscriptions = await prisma.vacancySubscription.findMany({
      where: { seekerId: seeker.id },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { subscriptions });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/subscriptions
export async function createSubscription(req: AuthRequest, res: Response): Promise<void> {
  const { query, city, salaryMin, employmentType } = req.body as {
    query?: string; city?: string; salaryMin?: number; employmentType?: string;
  };

  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { fail(res, 'Seeker profile not found'); return; }

    const subscription = await prisma.vacancySubscription.create({
      data: {
        seekerId:      seeker.id,
        query:         query         ?? null,
        city:          city          ?? null,
        salaryMin:     salaryMin     ?? null,
        employmentType: employmentType ?? null,
      },
    });

    ok(res, { subscription });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// DELETE /api/subscriptions/:id
export async function deleteSubscription(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { fail(res, 'Seeker profile not found'); return; }

    const sub = await prisma.vacancySubscription.findUnique({ where: { id } });
    if (!sub || sub.seekerId !== seeker.id) { fail(res, 'Subscription not found or access denied'); return; }

    await prisma.vacancySubscription.delete({ where: { id } });
    ok(res, { deleted: true });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
