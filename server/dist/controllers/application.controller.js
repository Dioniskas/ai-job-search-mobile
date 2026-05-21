"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createApplication = createApplication;
exports.getSeekerApplications = getSeekerApplications;
exports.getEmployerApplications = getEmployerApplications;
exports.deleteApplication = deleteApplication;
exports.updateApplicationStatus = updateApplicationStatus;
const response_1 = require("../utils/response");
const fcm_service_1 = require("../services/fcm.service");
const email_service_1 = require("../services/email.service");
const email_notifications_controller_1 = require("../controllers/email-notifications.controller");
const prisma_1 = __importDefault(require("../lib/prisma"));
// POST /api/applications
async function createApplication(req, res) {
    const { vacancyId, resumeId, coverLetter } = req.body;
    if (!vacancyId || !resumeId) {
        (0, response_1.fail)(res, 'vacancyId and resumeId are required');
        return;
    }
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
            return;
        }
        const vacancy = await prisma_1.default.vacancy.findUnique({
            where: { id: vacancyId },
            include: {
                employer: {
                    include: {
                        user: { select: { id: true, email: true, fcmToken: true, emailNotifications: true } },
                    },
                },
            },
        });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Vacancy not found');
            return;
        }
        const resume = await prisma_1.default.resume.findUnique({ where: { id: resumeId } });
        if (!resume || resume.seekerId !== seeker.id) {
            (0, response_1.fail)(res, 'Resume not found');
            return;
        }
        const application = await prisma_1.default.application.create({
            data: {
                vacancyId,
                resumeId,
                seekerId: seeker.id,
                employerId: vacancy.employerId,
                coverLetter: coverLetter ?? null,
            },
        });
        const employerUser = vacancy.employer.user;
        const seekerName = `${seeker.firstName} ${seeker.lastName}`.trim();
        const employerPrefs = (0, email_notifications_controller_1.getEmailPrefs)(employerUser.emailNotifications);
        // In-app notification
        await prisma_1.default.notification.create({
            data: {
                userId: employerUser.id,
                type: 'NEW_APPLICATION',
                text: `${seekerName} откликнулся на «${vacancy.title}»`,
                link: `/employer/applications`,
            },
        });
        // Push
        if (employerUser.fcmToken) {
            await (0, fcm_service_1.sendPush)(employerUser.fcmToken, 'Новый отклик', `${seekerName} откликнулся на «${vacancy.title}»`, { type: 'NEW_APPLICATION', applicationId: application.id });
        }
        // Email
        if (employerPrefs.newApplication) {
            (0, email_service_1.sendNewApplicationEmail)(employerUser.email, seekerName, vacancy.title).catch(() => { });
        }
        (0, response_1.ok)(res, { application });
    }
    catch (e) {
        if (e.code === 'P2002') {
            (0, response_1.fail)(res, 'Вы уже откликнулись на эту вакансию');
            return;
        }
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// GET /api/applications/seeker
async function getSeekerApplications(req, res) {
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.ok)(res, { data: [], total: 0, page: 1, totalPages: 0 });
            return;
        }
        const page = Math.max(1, parseInt(req.query['page'] ?? '1', 10));
        const limit = Math.min(50, Math.max(1, parseInt(req.query['limit'] ?? '20', 10)));
        const skip = (page - 1) * limit;
        const [applications, total] = await Promise.all([
            prisma_1.default.application.findMany({
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
            prisma_1.default.application.count({ where: { seekerId: seeker.id } }),
        ]);
        (0, response_1.ok)(res, { data: applications, total, page, totalPages: Math.ceil(total / limit) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// GET /api/applications/employer
async function getEmployerApplications(req, res) {
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.ok)(res, { data: [], total: 0, page: 1, totalPages: 0 });
            return;
        }
        const page = Math.max(1, parseInt(req.query['page'] ?? '1', 10));
        const limit = Math.min(50, Math.max(1, parseInt(req.query['limit'] ?? '20', 10)));
        const skip = (page - 1) * limit;
        const [applications, total] = await Promise.all([
            prisma_1.default.application.findMany({
                where: { employerId: employer.id },
                include: {
                    vacancy: { select: { id: true, title: true } },
                    resume: {
                        include: {
                            // eslint-disable-next-line @typescript-eslint/no-explicit-any
                            seeker: { select: { firstName: true, lastName: true, photoUrl: true, city: true, searchStatus: true } },
                        },
                    },
                },
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma_1.default.application.count({ where: { employerId: employer.id } }),
        ]);
        (0, response_1.ok)(res, { data: applications, total, page, totalPages: Math.ceil(total / limit) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// DELETE /api/applications/:id
async function deleteApplication(req, res) {
    const { id } = req.params;
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId: req.user.userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Seeker profile not found');
            return;
        }
        const app = await prisma_1.default.application.findUnique({ where: { id } });
        if (!app || app.seekerId !== seeker.id) {
            (0, response_1.fail)(res, 'Application not found or access denied', 404);
            return;
        }
        if (app.status !== 'PENDING') {
            (0, response_1.fail)(res, `Нельзя отменить отклик со статусом ${app.status}`, 400);
            return;
        }
        await prisma_1.default.application.delete({ where: { id } });
        (0, response_1.ok)(res, { deleted: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// PATCH /api/applications/:id/status
async function updateApplicationStatus(req, res) {
    const { id } = req.params;
    const { status } = req.body;
    const allowed = ['PENDING', 'VIEWED', 'ACCEPTED', 'REJECTED'];
    if (!status || !allowed.includes(status)) {
        (0, response_1.fail)(res, 'Invalid status');
        return;
    }
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { userId: req.user.userId } });
        if (!employer) {
            (0, response_1.fail)(res, 'Employer profile not found');
            return;
        }
        const app = await prisma_1.default.application.findUnique({ where: { id } });
        if (!app || app.employerId !== employer.id) {
            (0, response_1.fail)(res, 'Application not found or access denied');
            return;
        }
        const updated = await prisma_1.default.application.update({
            where: { id },
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            data: { status: status },
        });
        const [vacancy, seeker, employerProfile] = await Promise.all([
            prisma_1.default.vacancy.findUnique({
                where: { id: app.vacancyId },
                select: { title: true },
            }),
            prisma_1.default.seekerProfile.findUnique({
                where: { id: app.seekerId },
                select: {
                    firstName: true,
                    lastName: true,
                    user: { select: { id: true, email: true, fcmToken: true, emailNotifications: true } },
                },
            }),
            prisma_1.default.employer.findUnique({
                where: { id: app.employerId },
                select: { companyName: true },
            }),
        ]);
        if (seeker && vacancy) {
            const statusTexts = {
                VIEWED: `Работодатель просмотрел ваш отклик на «${vacancy.title}»`,
                ACCEPTED: `Ваш отклик на «${vacancy.title}» принят — ждите приглашения!`,
                REJECTED: `По вакансии «${vacancy.title}» вы не подошли`,
            };
            const notifText = statusTexts[status];
            if (notifText) {
                // In-app notification
                await prisma_1.default.notification.create({
                    data: {
                        userId: seeker.user.id,
                        type: 'APPLICATION_STATUS',
                        text: notifText,
                        link: `/seeker/applications`,
                    },
                });
                // Push
                if (seeker.user.fcmToken) {
                    const pushTitles = {
                        VIEWED: 'Резюме просмотрено',
                        ACCEPTED: 'Отклик принят!',
                        REJECTED: 'Результат отклика',
                    };
                    await (0, fcm_service_1.sendPush)(seeker.user.fcmToken, pushTitles[status] ?? 'Обновление отклика', notifText, { type: 'APPLICATION_STATUS', status, applicationId: id });
                }
                // Email
                const seekerPrefs = (0, email_notifications_controller_1.getEmailPrefs)(seeker.user.emailNotifications);
                if (status === 'ACCEPTED' && seekerPrefs.interview) {
                    // ACCEPTED = interview invitation
                    const seekerName = `${seeker.firstName} ${seeker.lastName}`.trim();
                    const companyName = employerProfile?.companyName ?? 'Работодатель';
                    (0, email_service_1.sendInterviewInvitationEmail)(seeker.user.email, seekerName, vacancy.title, companyName).catch(() => { });
                }
                else if (seekerPrefs.applicationStatus && (status === 'VIEWED' || status === 'REJECTED')) {
                    (0, email_service_1.sendApplicationStatusEmail)(seeker.user.email, vacancy.title, status).catch(() => { });
                }
            }
        }
        (0, response_1.ok)(res, { application: updated });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
