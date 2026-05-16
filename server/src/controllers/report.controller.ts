import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

const SPAM_THRESHOLD = 3;

export async function createReport(req: AuthRequest, res: Response): Promise<void> {
  const { targetId, targetType, reason } = req.body as {
    targetId?: string;
    targetType?: string;
    reason?: string;
  };

  if (!targetId || !targetType || !reason) {
    fail(res, 'targetId, targetType и reason обязательны'); return;
  }
  if (targetType !== 'vacancy' && targetType !== 'user') {
    fail(res, 'targetType должен быть "vacancy" или "user"'); return;
  }

  try {
    const report = await prisma.report.create({
      data: {
        reporterId: req.user!.userId,
        targetId,
        targetType,
        reason,
      },
    });

    // Auto-block spam: if 3+ reports on a user → hide their vacancies
    if (targetType === 'user') {
      const count = await prisma.report.count({
        where: { targetId, targetType: 'user' },
      });

      if (count >= SPAM_THRESHOLD) {
        const user = await prisma.user.findUnique({ where: { id: targetId } });
        if (user && user.role === 'EMPLOYER') {
          const employer = await prisma.employer.findUnique({ where: { userId: targetId } });
          if (employer) {
            await prisma.vacancy.updateMany({
              where: { employerId: employer.id, isActive: true },
              data: { isActive: false },
            });
          }
        }
      }
    }

    ok(res, { report }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
