"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSeekerApplications = getSeekerApplications;
exports.getEmployerApplications = getEmployerApplications;
exports.updateApplicationStatus = updateApplicationStatus;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const client_1 = require("@prisma/client");
// ── Seeker: list own applications ──────────────────────────────────────────────
async function getSeekerApplications(req, res) {
    try {
        const seeker = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        if (!seeker) {
            (0, response_1.ok)(res, { applications: [] });
            return;
        }
        const applications = await prisma_1.default.application.findMany({
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
        (0, response_1.ok)(res, { applications });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Employer: list applications for own vacancies ──────────────────────────────
async function getEmployerApplications(req, res) {
    try {
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.ok)(res, { applications: [] });
            return;
        }
        const applications = await prisma_1.default.application.findMany({
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
        (0, response_1.ok)(res, { applications });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ── Employer: update application status ────────────────────────────────────────
async function updateApplicationStatus(req, res) {
    try {
        const { id } = req.params;
        const { status } = req.body;
        const validStatuses = Object.values(client_1.ApplicationStatus);
        if (!validStatuses.includes(status)) {
            (0, response_1.fail)(res, `status должен быть одним из: ${validStatuses.join(', ')}`);
            return;
        }
        const employer = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        if (!employer) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const app = await prisma_1.default.application.findFirst({
            where: { id, employerId: employer.id },
            include: {
                seeker: { select: { userId: true } },
                vacancy: { select: { title: true } },
            },
        });
        if (!app) {
            (0, response_1.fail)(res, 'Отклик не найден', 404);
            return;
        }
        const updated = await prisma_1.default.application.update({
            where: { id },
            data: { status: status },
        });
        // Notify seeker about status change
        const statusText = {
            VIEWED: 'просмотрен',
            ACCEPTED: 'принят',
            REJECTED: 'отклонён',
        };
        if (statusText[status]) {
            await prisma_1.default.notification.create({
                data: {
                    userId: app.seeker.userId,
                    type: 'APPLICATION_STATUS',
                    text: `Ваш отклик на вакансию "${app.vacancy.title}" ${statusText[status]}`,
                },
            }).catch(() => null);
        }
        (0, response_1.ok)(res, { application: updated });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
