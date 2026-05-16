import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

async function findSeeker(req: AuthRequest) {
  return prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
}

// GET /api/saved
export async function getSavedVacancies(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await findSeeker(req);
    if (!seeker) { ok(res, { saved: [] }); return; }

    const saved = await prisma.savedVacancy.findMany({
      where: { seekerId: seeker.id },
      include: {
        vacancy: {
          include: { employer: { select: { companyName: true, logoUrl: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { saved });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/saved/:vacancyId
export async function saveVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyId } = req.params;
  try {
    const seeker = await findSeeker(req);
    if (!seeker) { fail(res, 'Seeker profile not found'); return; }

    const record = await prisma.savedVacancy.upsert({
      where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
      create: { seekerId: seeker.id, vacancyId },
      update: {},
    });

    ok(res, { saved: record });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// DELETE /api/saved/:vacancyId
export async function unsaveVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyId } = req.params;
  try {
    const seeker = await findSeeker(req);
    if (!seeker) { fail(res, 'Seeker profile not found'); return; }

    await prisma.savedVacancy.deleteMany({ where: { seekerId: seeker.id, vacancyId } });

    ok(res, { deleted: true });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// GET /api/saved/:vacancyId/check
export async function checkSavedVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyId } = req.params;
  try {
    const seeker = await findSeeker(req);
    if (!seeker) { ok(res, { isSaved: false }); return; }

    const record = await prisma.savedVacancy.findUnique({
      where: { seekerId_vacancyId: { seekerId: seeker.id, vacancyId } },
    });

    ok(res, { isSaved: !!record });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
