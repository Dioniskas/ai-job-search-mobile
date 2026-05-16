import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { sendPush } from '../services/fcm.service';
import {
  sendNewApplicationEmail,
  sendApplicationStatusEmail,
  sendInterviewInvitationEmail,
} from '../services/email.service';
import { getEmailPrefs } from '../controllers/email-notifications.controller';
import prisma from '../lib/prisma';

// POST /api/applications
export async function createApplication(req: AuthRequest, res: Response): Promise<void> {
  const { vacancyId, resumeId, coverLetter } = req.body as {
    vacancyId: string;
    resumeId: string;
    coverLetter?: string;
  };

  if (!vacancyId || !resumeId) { fail(res, 'vacancyId and resumeId are required'); return; }

  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { fail(res, 'Seeker profile not found'); return; }

    const vacancy = await prisma.vacancy.findUnique({
      where: { id: vacancyId },
      include: {
        employer: {
          include: {
            user: { select: { id: true, email: true, fcmToken: true, emailNotifications: true } },
          },
        },
      },
    });
    if (!vacancy) { fail(res, 'Vacancy not found'); return; }

    const resume = await prisma.resume.findUnique({ where: { id: resumeId } });
    if (!resume || resume.seekerId !== seeker.id) { fail(res, 'Resume not found'); return; }

    const application = await prisma.application.create({
      data: {
        vacancyId,
        resumeId,
        seekerId: seeker.id,
        employerId: vacancy.employerId,
        coverLetter: coverLetter ?? null,
      },
    });

    const employerUser    = vacancy.employer.user;
    const seekerName      = `${seeker.firstName} ${seeker.lastName}`.trim();
    const employerPrefs   = getEmailPrefs(employerUser.emailNotifications);

    // In-app notification
    await prisma.notification.create({
      data: {
        userId: employerUser.id,
        type:   'NEW_APPLICATION',
        text:   `${seekerName} откликнулся на «${vacancy.title}»`,
        link:   `/employer/applications`,
      },
    });

    // Push
    if (employerUser.fcmToken) {
      await sendPush(
        employerUser.fcmToken,
        'Новый отклик',
        `${seekerName} откликнулся на «${vacancy.title}»`,
        { type: 'NEW_APPLICATION', applicationId: application.id },
      );
    }

    // Email
    if (employerPrefs.newApplication) {
      sendNewApplicationEmail(employerUser.email, seekerName, vacancy.title).catch(() => {});
    }

    ok(res, { application });
  } catch (e) {
    if ((e as { code?: string }).code === 'P2002') {
      fail(res, 'Вы уже откликнулись на эту вакансию');
      return;
    }
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// GET /api/applications/seeker
export async function getSeekerApplications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const seeker = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!seeker) { ok(res, { data: [], total: 0, page: 1, totalPages: 0 }); return; }

    const page  = Math.max(1, parseInt(req.query['page']  as string ?? '1',  10));
    const limit = Math.min(50, Math.max(1, parseInt(req.query['limit'] as string ?? '20', 10)));
    const skip  = (page - 1) * limit;

    const [applications, total] = await Promise.all([
      prisma.application.findMany({
        where: { seekerId: seeker.id },
        include: {
          vacancy: {
            include: { employer: { select: { companyName: true, logoUrl: true } } },
          },
          resume: { select: { id: true, title: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.application.count({ where: { seekerId: seeker.id } }),
    ]);

    ok(res, { data: applications, total, page, totalPages: Math.ceil(total / limit) });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// GET /api/applications/employer
export async function getEmployerApplications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { ok(res, { data: [], total: 0, page: 1, totalPages: 0 }); return; }

    const page  = Math.max(1, parseInt(req.query['page']  as string ?? '1',  10));
    const limit = Math.min(50, Math.max(1, parseInt(req.query['limit'] as string ?? '20', 10)));
    const skip  = (page - 1) * limit;

    const [applications, total] = await Promise.all([
      prisma.application.findMany({
        where: { employerId: employer.id },
        include: {
          vacancy: { select: { id: true, title: true } },
          resume: {
            include: {
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              seeker: { select: { firstName: true, lastName: true, photoUrl: true, city: true, searchStatus: true } as any },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.application.count({ where: { employerId: employer.id } }),
    ]);

    ok(res, { data: applications, total, page, totalPages: Math.ceil(total / limit) });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// PATCH /api/applications/:id/status
export async function updateApplicationStatus(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  const { status } = req.body as { status: string };

  const allowed = ['PENDING', 'VIEWED', 'ACCEPTED', 'REJECTED'];
  if (!status || !allowed.includes(status)) { fail(res, 'Invalid status'); return; }

  try {
    const employer = await prisma.employer.findUnique({ where: { userId: req.user!.userId } });
    if (!employer) { fail(res, 'Employer profile not found'); return; }

    const app = await prisma.application.findUnique({ where: { id } });
    if (!app || app.employerId !== employer.id) { fail(res, 'Application not found or access denied'); return; }

    const updated = await prisma.application.update({
      where: { id },
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      data: { status: status as any },
    });

    const [vacancy, seeker, employerProfile] = await Promise.all([
      prisma.vacancy.findUnique({
        where: { id: app.vacancyId },
        select: { title: true },
      }),
      prisma.seekerProfile.findUnique({
        where: { id: app.seekerId },
        select: {
          firstName: true,
          lastName: true,
          user: { select: { id: true, email: true, fcmToken: true, emailNotifications: true } },
        },
      }),
      prisma.employer.findUnique({
        where: { id: app.employerId },
        select: { companyName: true },
      }),
    ]);

    if (seeker && vacancy) {
      const statusTexts: Record<string, string> = {
        VIEWED:   `Работодатель просмотрел ваш отклик на «${vacancy.title}»`,
        ACCEPTED: `Ваш отклик на «${vacancy.title}» принят — ждите приглашения!`,
        REJECTED: `По вакансии «${vacancy.title}» вы не подошли`,
      };
      const notifText = statusTexts[status];

      if (notifText) {
        // In-app notification
        await prisma.notification.create({
          data: {
            userId: seeker.user.id,
            type:   'APPLICATION_STATUS',
            text:   notifText,
            link:   `/seeker/applications`,
          },
        });

        // Push
        if (seeker.user.fcmToken) {
          const pushTitles: Record<string, string> = {
            VIEWED:   'Резюме просмотрено',
            ACCEPTED: 'Отклик принят!',
            REJECTED: 'Результат отклика',
          };
          await sendPush(
            seeker.user.fcmToken,
            pushTitles[status] ?? 'Обновление отклика',
            notifText,
            { type: 'APPLICATION_STATUS', status, applicationId: id },
          );
        }

        // Email
        const seekerPrefs = getEmailPrefs(seeker.user.emailNotifications);

        if (status === 'ACCEPTED' && seekerPrefs.interview) {
          // ACCEPTED = interview invitation
          const seekerName   = `${seeker.firstName} ${seeker.lastName}`.trim();
          const companyName  = employerProfile?.companyName ?? 'Работодатель';
          sendInterviewInvitationEmail(
            seeker.user.email,
            seekerName,
            vacancy.title,
            companyName,
          ).catch(() => {});
        } else if (seekerPrefs.applicationStatus && (status === 'VIEWED' || status === 'REJECTED')) {
          sendApplicationStatusEmail(seeker.user.email, vacancy.title, status).catch(() => {});
        }
      }
    }

    ok(res, { application: updated });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
