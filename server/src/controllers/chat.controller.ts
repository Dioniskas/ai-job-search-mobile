import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import { getIo } from '../lib/io';

export async function getConversations(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId, role } = req.user!;

    if (role === 'SEEKER') {
      const seeker = await prisma.seekerProfile.findUnique({ where: { userId } });
      if (!seeker) { fail(res, 'Профиль соискателя не найден', 404); return; }

      const applications = await prisma.application.findMany({
        where: { seekerId: seeker.id },
        include: {
          vacancy: { select: { title: true } },
          employer: { select: { companyName: true, logoUrl: true } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
        orderBy: { createdAt: 'desc' },
      });

      const conversations = await Promise.all(
        applications.map(async (app) => {
          const unreadCount = await prisma.message.count({
            where: { applicationId: app.id, receiverId: userId, isRead: false },
          });
          return {
            applicationId: app.id,
            partyName: app.employer.companyName,
            partyAvatar: app.employer.logoUrl,
            vacancyTitle: app.vacancy.title,
            lastMessage: app.messages[0] ?? null,
            unreadCount,
            status: app.status,
          };
        })
      );

      ok(res, { conversations });
    } else {
      const employer = await prisma.employer.findUnique({ where: { userId } });
      if (!employer) { fail(res, 'Профиль работодателя не найден', 404); return; }

      const applications = await prisma.application.findMany({
        where: { employerId: employer.id },
        include: {
          seeker: { select: { firstName: true, lastName: true, photoUrl: true } },
          vacancy: { select: { title: true } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
        orderBy: { createdAt: 'desc' },
      });

      const conversations = await Promise.all(
        applications.map(async (app) => {
          const unreadCount = await prisma.message.count({
            where: { applicationId: app.id, receiverId: userId, isRead: false },
          });
          return {
            applicationId: app.id,
            partyName: `${app.seeker.firstName} ${app.seeker.lastName}`,
            partyAvatar: app.seeker.photoUrl,
            vacancyTitle: app.vacancy.title,
            lastMessage: app.messages[0] ?? null,
            unreadCount,
            status: app.status,
          };
        })
      );

      ok(res, { conversations });
    }
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getMessages(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;
    const { applicationId } = req.params;

    const application = await prisma.application.findUnique({
      where: { id: applicationId },
      include: {
        seeker: { select: { userId: true } },
        employer: { select: { userId: true } },
      },
    });

    if (!application) { fail(res, 'Отклик не найден', 404); return; }

    const isParticipant =
      application.seeker.userId === userId || application.employer.userId === userId;
    if (!isParticipant) { fail(res, 'Доступ запрещён', 403); return; }

    await prisma.message.updateMany({
      where: { applicationId, receiverId: userId, isRead: false },
      data: { isRead: true },
    });

    const messages = await prisma.message.findMany({
      where: { applicationId },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        senderId: true,
        receiverId: true,
        applicationId: true,
        text: true,
        isRead: true,
        createdAt: true,
      },
    });

    ok(res, { messages });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function sendMessage(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;
    const { applicationId } = req.params;
    const { text } = req.body as { text: string };

    if (!text?.trim()) { fail(res, 'Текст сообщения обязателен'); return; }

    const application = await prisma.application.findUnique({
      where: { id: applicationId },
      include: {
        seeker: { select: { userId: true } },
        employer: { select: { userId: true } },
      },
    });

    if (!application) { fail(res, 'Отклик не найден', 404); return; }

    const isSeeker = application.seeker.userId === userId;
    const isEmployer = application.employer.userId === userId;

    if (!isSeeker && !isEmployer) { fail(res, 'Доступ запрещён', 403); return; }

    const receiverId = isSeeker ? application.employer.userId : application.seeker.userId;

    const message = await prisma.message.create({
      data: { senderId: userId, receiverId, applicationId, text: text.trim() },
      select: {
        id: true,
        senderId: true,
        receiverId: true,
        applicationId: true,
        text: true,
        isRead: true,
        createdAt: true,
      },
    });

    try {
      getIo().to(`app_${applicationId}`).emit('new_message', message);
    } catch {
      // Socket not yet initialized or no active room; REST response is sufficient
    }

    ok(res, { message }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
