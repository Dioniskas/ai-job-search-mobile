"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createAdmin = createAdmin;
exports.getDashboard = getDashboard;
exports.getUsers = getUsers;
exports.getUserDetail = getUserDetail;
exports.blockUser = blockUser;
exports.unblockUser = unblockUser;
exports.getVacancies = getVacancies;
exports.moderateVacancy = moderateVacancy;
exports.rejectVacancy = rejectVacancy;
exports.getEmployers = getEmployers;
exports.verifyEmployer = verifyEmployer;
exports.getReports = getReports;
exports.resolveReport = resolveReport;
exports.getPayments = getPayments;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
// ─── Create first admin (public, only if none exists) ─────────────────────────
async function createAdmin(req, res) {
    const { email, password } = req.body;
    if (!email || !password) {
        (0, response_1.fail)(res, 'Email и пароль обязательны');
        return;
    }
    try {
        const existing = await prisma_1.default.user.findFirst({ where: { role: 'ADMIN' } });
        if (existing) {
            (0, response_1.fail)(res, 'Администратор уже существует', 409);
            return;
        }
        const hash = await bcryptjs_1.default.hash(password, 10);
        const admin = await prisma_1.default.user.create({
            data: { email, password: hash, role: 'ADMIN' },
        });
        (0, response_1.ok)(res, { id: admin.id, email: admin.email }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Dashboard ────────────────────────────────────────────────────────────────
async function getDashboard(_req, res) {
    try {
        const [totalUsers, totalSeekers, totalEmployers, totalVacancies, activeVacancies, unmModeratedVacancies, totalApplications, revenueAgg, recentUsers, recentPayments,] = await Promise.all([
            prisma_1.default.user.count(),
            prisma_1.default.user.count({ where: { role: 'SEEKER' } }),
            prisma_1.default.user.count({ where: { role: 'EMPLOYER' } }),
            prisma_1.default.vacancy.count(),
            prisma_1.default.vacancy.count({ where: { isActive: true } }),
            prisma_1.default.vacancy.count({ where: { isModerated: false, isActive: true } }),
            prisma_1.default.application.count(),
            prisma_1.default.payment.aggregate({ _sum: { amount: true }, where: { status: 'PAID' } }),
            prisma_1.default.user.findMany({
                take: 5, orderBy: { createdAt: 'desc' },
                select: { id: true, email: true, role: true, isBlocked: true, createdAt: true },
            }),
            prisma_1.default.payment.findMany({
                take: 5, orderBy: { createdAt: 'desc' },
                include: { user: { select: { email: true } } },
            }),
        ]);
        (0, response_1.ok)(res, {
            stats: {
                totalUsers, totalSeekers, totalEmployers,
                totalVacancies, activeVacancies, unmModeratedVacancies,
                totalApplications, totalRevenue: revenueAgg._sum.amount ?? 0,
            },
            recentUsers,
            recentPayments,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Users ────────────────────────────────────────────────────────────────────
async function getUsers(req, res) {
    const { search = '', role, page = '1', limit = '20' } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (role)
        where.role = role;
    if (search)
        where.email = { contains: search, mode: 'insensitive' };
    try {
        const [users, total] = await Promise.all([
            prisma_1.default.user.findMany({
                where, skip, take: Number(limit),
                orderBy: { createdAt: 'desc' },
                select: {
                    id: true, email: true, role: true, isBlocked: true, createdAt: true,
                    seekerProfile: { select: { firstName: true, lastName: true, city: true } },
                    employerProfile: { select: { companyName: true, isVerified: true } },
                },
            }),
            prisma_1.default.user.count({ where }),
        ]);
        (0, response_1.ok)(res, { users, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getUserDetail(req, res) {
    try {
        const user = await prisma_1.default.user.findUnique({
            where: { id: req.params.id },
            include: {
                seekerProfile: { include: { resumes: true, skillTests: true } },
                employerProfile: { include: { vacancies: { take: 5, orderBy: { createdAt: 'desc' } } } },
                payments: { take: 10, orderBy: { createdAt: 'desc' } },
            },
        });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        (0, response_1.ok)(res, user);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function blockUser(req, res) {
    const { id } = req.params;
    try {
        const user = await prisma_1.default.user.findUnique({ where: { id } });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        await prisma_1.default.user.update({ where: { id }, data: { isBlocked: true } });
        if (user.role === 'EMPLOYER') {
            const employer = await prisma_1.default.employer.findUnique({ where: { userId: id } });
            if (employer) {
                await prisma_1.default.vacancy.updateMany({ where: { employerId: employer.id }, data: { isActive: false } });
            }
        }
        (0, response_1.ok)(res, { blocked: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function unblockUser(req, res) {
    const { id } = req.params;
    try {
        const user = await prisma_1.default.user.findUnique({ where: { id } });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        await prisma_1.default.user.update({ where: { id }, data: { isBlocked: false } });
        (0, response_1.ok)(res, { unblocked: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Vacancies ────────────────────────────────────────────────────────────────
async function getVacancies(req, res) {
    const { moderated, page = '1', limit = '20' } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (moderated !== undefined)
        where.isModerated = moderated === 'true';
    try {
        const [vacancies, total] = await Promise.all([
            prisma_1.default.vacancy.findMany({
                where, skip, take: Number(limit),
                orderBy: { createdAt: 'desc' },
                include: {
                    employer: { select: { companyName: true, isVerified: true } },
                    _count: { select: { applications: true } },
                },
            }),
            prisma_1.default.vacancy.count({ where }),
        ]);
        (0, response_1.ok)(res, { vacancies, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function moderateVacancy(req, res) {
    const { id } = req.params;
    try {
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        await prisma_1.default.vacancy.update({ where: { id }, data: { isModerated: true, isActive: true } });
        (0, response_1.ok)(res, { moderated: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function rejectVacancy(req, res) {
    const { id } = req.params;
    try {
        const vacancy = await prisma_1.default.vacancy.findUnique({ where: { id } });
        if (!vacancy) {
            (0, response_1.fail)(res, 'Вакансия не найдена', 404);
            return;
        }
        await prisma_1.default.vacancy.update({ where: { id }, data: { isActive: false, isModerated: true } });
        (0, response_1.ok)(res, { rejected: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Employers ────────────────────────────────────────────────────────────────
async function getEmployers(req, res) {
    const { verified, page = '1', limit = '20' } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (verified !== undefined)
        where.isVerified = verified === 'true';
    try {
        const [employers, total] = await Promise.all([
            prisma_1.default.employer.findMany({
                where, skip, take: Number(limit),
                orderBy: { id: 'desc' },
                include: {
                    user: { select: { email: true, isBlocked: true, createdAt: true } },
                    _count: { select: { vacancies: true } },
                },
            }),
            prisma_1.default.employer.count({ where }),
        ]);
        (0, response_1.ok)(res, { employers, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function verifyEmployer(req, res) {
    const { id } = req.params;
    try {
        const employer = await prisma_1.default.employer.findUnique({ where: { id } });
        if (!employer) {
            (0, response_1.fail)(res, 'Работодатель не найден', 404);
            return;
        }
        await prisma_1.default.employer.update({ where: { id }, data: { isVerified: true } });
        (0, response_1.ok)(res, { verified: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Reports ──────────────────────────────────────────────────────────────────
async function getReports(req, res) {
    const { resolved, page = '1', limit = '20' } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (resolved !== undefined)
        where.isResolved = resolved === 'true';
    try {
        const [reports, total] = await Promise.all([
            prisma_1.default.report.findMany({
                where, skip, take: Number(limit),
                orderBy: { createdAt: 'desc' },
                include: { reporter: { select: { email: true } } },
            }),
            prisma_1.default.report.count({ where }),
        ]);
        (0, response_1.ok)(res, { reports, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function resolveReport(req, res) {
    const { id } = req.params;
    try {
        const report = await prisma_1.default.report.findUnique({ where: { id } });
        if (!report) {
            (0, response_1.fail)(res, 'Жалоба не найдена', 404);
            return;
        }
        await prisma_1.default.report.update({
            where: { id },
            data: { isResolved: true, resolvedAt: new Date() },
        });
        (0, response_1.ok)(res, { resolved: true });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// ─── Payments ─────────────────────────────────────────────────────────────────
async function getPayments(req, res) {
    const { page = '1', limit = '20', status } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (status)
        where.status = status;
    try {
        const [payments, total, revenueAgg] = await Promise.all([
            prisma_1.default.payment.findMany({
                where, skip, take: Number(limit),
                orderBy: { createdAt: 'desc' },
                include: { user: { select: { email: true } } },
            }),
            prisma_1.default.payment.count({ where }),
            prisma_1.default.payment.aggregate({ _sum: { amount: true }, where: { status: 'PAID' } }),
        ]);
        (0, response_1.ok)(res, {
            payments, total,
            page: Number(page),
            pages: Math.ceil(total / Number(limit)),
            totalRevenue: revenueAgg._sum.amount ?? 0,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
