import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import { ApplicationStatus } from '@prisma/client';

// ── Seeker: list own applications ──────────────────────────────────────────────
export async function getSeekerApplications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!seeker) { ok(res, { applications: [] }); return; }

    const applications = await prisma.application.findMany({
      where: { seekerId: seeker.id },
      include: {
        vacancy: {
          select: {
            id: true,
            title: true,
            salaryMin: true,
            salaryMax: true,
            city: true,
            employer: { select: { companyName: true, logoUrl: true } },
          },
        },
        resume: { select: { title: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { applications });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Employer: list applications for own vacancies ──────────────────────────────
export async function getEmployerApplications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { ok(res, { applications: [] }); return; }

    const applications = await prisma.application.findMany({
      where: { employerId: employer.id },
      include: {
        vacancy: { select: { id: true, title: true } },
        resume: {
          select: {
            id: true,
            title: true,
            skills: true,
            seeker: {
              select: {
                firstName: true,
                lastName: true,
                city: true,
                photoUrl: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    ok(res, { applications });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ── Employer: update application status ────────────────────────────────────────
export async function updateApplicationStatus(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params as { id: string };
    const { status } = req.body as { status: string };

    const validStatuses = Object.values(ApplicationStatus);
    if (!validStatuses.includes(status as ApplicationStatus)) {
      fail(res, `status должен быть одним из: ${validStatuses.join(', ')}`); return;
    }

    const employer = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    if (!employer) { fail(res, 'Профиль не найден', 404); return; }

    const app = await prisma.application.findFirst({
      where: { id, employerId: employer.id },
      include: {
        seeker: { select: { userId: true } },
        vacancy: { select: { title: true } },
      },
    });
    if (!app) { fail(res, 'Отклик не найден', 404); return; }

    const updated = await prisma.application.update({
      where: { id },
      data: { status: status as ApplicationStatus },
    });

    // Notify seeker about status change
    const statusText: Record<string, string> = {
      VIEWED:   'просмотрен',
      ACCEPTED: 'принят',
      REJECTED: 'отклонён',
    };
    if (statusText[status]) {
      await prisma.notification.create({
        data: {
          userId: app.seeker.userId,
          type: 'APPLICATION_STATUS',
          text: `Ваш отклик на вакансию "${app.vacancy.title}" ${statusText[status]}`,
        },
      }).catch(() => null);
    }

    ok(res, { application: updated });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
