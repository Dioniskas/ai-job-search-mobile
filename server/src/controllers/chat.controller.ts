import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { sendPush } from '../services/fcm.service';
import prisma from '../lib/prisma';

// GET /api/chat/conversations
export async function getConversations(req: AuthRequest, res: Response): Promise<void> {
  try {
    const userId = req.user!.userId;

    // Find all applications where this user is seeker or employer
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        seekerProfile: { select: { id: true, applications: { select: { id: true } } } },
        employerProfile: { select: { id: true, applications: { select: { id: true } } } },
      },
    });
    if (!user) { fail(res, 'User not found'); return; }

    const appIds = user.role === 'SEEKER'
      ? (user.seekerProfile?.applications ?? []).map(a => a.id)
      : (user.employerProfile?.applications ?? []).map(a => a.id);

    if (appIds.length === 0) { ok(res, { conversations: [] }); return; }

    // Get last message per application
    const conversations = await Promise.all(
      appIds.map(async (applicationId) => {
        const [lastMessage, unreadCount, application] = await Promise.all([
          prisma.message.findFirst({
            where: { applicationId },
            orderBy: { createdAt: 'desc' },
          }),
          prisma.message.count({
            where: { applicationId, receiverId: userId, isRead: false },
          }),
          prisma.application.findUnique({
            where: { id: applicationId },
            include: {
              vacancy: { select: { id: true, title: true } },
              resume: {
                include: {
                  seeker: { select: { firstName: true, lastName: true, photoUrl: true } },
                },
              },
              employer: { select: { companyName: true, logoUrl: true } },
            },
          }),
        ]);

        if (!application || !lastMessage) return null;
        return { applicationId, application, lastMessage, unreadCount };
      }),
    );

    const result = conversations
      .filter(Boolean)
      .sort((a, b) =>
        new Date(b!.lastMessage.createdAt).getTime() - new Date(a!.lastMessage.createdAt).getTime(),
      );

    ok(res, { conversations: result });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// GET /api/chat/:applicationId/messages
export async function getMessages(req: AuthRequest, res: Response): Promise<void> {
  const { applicationId } = req.params;
  const userId = req.user!.userId;

  try {
    const application = await prisma.application.findUnique({ where: { id: applicationId } });
    if (!application) { fail(res, 'Application not found'); return; }

    // Verify access: user must be seeker or employer on this application
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        seekerProfile: { select: { id: true } },
        employerProfile: { select: { id: true } },
      },
    });
    const hasAccess =
      (user?.seekerProfile?.id && user.seekerProfile.id === application.seekerId) ||
      (user?.employerProfile?.id && user.employerProfile.id === application.employerId);
    if (!hasAccess) { fail(res, 'Access denied', 403); return; }

    const messages = await prisma.message.findMany({
      where: { applicationId },
      orderBy: { createdAt: 'asc' },
    });

    // Mark received messages as read
    await prisma.message.updateMany({
      where: { applicationId, receiverId: userId, isRead: false },
      data: { isRead: true },
    });

    ok(res, { messages });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/chat/:applicationId/messages
export async function sendMessage(req: AuthRequest, res: Response): Promise<void> {
  const { applicationId } = req.params;
  const { text } = req.body as { text?: string };
  const senderId = req.user!.userId;

  if (!text?.trim()) { fail(res, 'text is required'); return; }

  try {
    const application = await prisma.application.findUnique({
      where: { id: applicationId },
      include: {
        vacancy: { select: { title: true } },
        resume: { include: { seeker: { include: { user: { select: { id: true, fcmToken: true } } } } } },
        employer: { include: { user: { select: { id: true, fcmToken: true } } } },
      },
    });
    if (!application) { fail(res, 'Application not found'); return; }

    // Determine sender/receiver
    const seekerUserId   = application.resume.seeker.user.id;
    const employerUserId = application.employer.user.id;

    let receiverId: string;
    let receiverFcmToken: string | null;
    let senderName: string;

    if (senderId === seekerUserId) {
      receiverId = employerUserId;
      receiverFcmToken = application.employer.user.fcmToken;
      const s = application.resume.seeker;
      senderName = `${s.firstName} ${s.lastName}`.trim();
    } else if (senderId === employerUserId) {
      receiverId = seekerUserId;
      receiverFcmToken = application.resume.seeker.user.fcmToken;
      senderName = application.employer.companyName;
    } else {
      fail(res, 'Access denied', 403);
      return;
    }

    const message = await prisma.message.create({
      data: { senderId, receiverId, applicationId, text: text.trim() },
    });

    // Push to receiver
    if (receiverFcmToken) {
      await sendPush(
        receiverFcmToken,
        `Сообщение от ${senderName}`,
        text.trim().length > 80 ? text.trim().slice(0, 77) + '...' : text.trim(),
        { type: 'NEW_MESSAGE', applicationId },
      );
    }

    ok(res, { message });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
