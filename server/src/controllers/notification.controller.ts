import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

// GET /api/notifications
export async function getNotifications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;

    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.notification.count({
        where: { userId, isRead: false },
      }),
    ]);

    ok(res, { notifications, unreadCount });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// PATCH /api/notifications/read
export async function markNotificationsRead(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;

    await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });

    ok(res, { marked: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
