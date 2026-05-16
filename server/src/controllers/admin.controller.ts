import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

// ─── Create first admin (public, only if none exists) ─────────────────────────

export async function createAdmin(req: Request, res: Response): Promise<void> {
  const { email, password } = req.body as { email: string; password: string };
  if (!email || !password) { fail(res, 'Email и пароль обязательны'); return; }

  try {
    const existing = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
    if (existing) { fail(res, 'Администратор уже существует', 409); return; }

    const hash = await bcrypt.hash(password, 10);
    const admin = await prisma.user.create({
      data: { email, password: hash, role: 'ADMIN' },
    });
    ok(res, { id: admin.id, email: admin.email }, 201);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

export async function getDashboard(_req: AuthRequest, res: Response): Promise<void> {
  try {
    const [
      totalUsers, totalSeekers, totalEmployers,
      totalVacancies, activeVacancies, unmModeratedVacancies,
      totalApplications, revenueAgg, recentUsers, recentPayments,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { role: 'SEEKER' } }),
      prisma.user.count({ where: { role: 'EMPLOYER' } }),
      prisma.vacancy.count(),
      prisma.vacancy.count({ where: { isActive: true } }),
      prisma.vacancy.count({ where: { isModerated: false, isActive: true } }),
      prisma.application.count(),
      prisma.payment.aggregate({ _sum: { amount: true }, where: { status: 'PAID' } }),
      prisma.user.findMany({
        take: 5, orderBy: { createdAt: 'desc' },
        select: { id: true, email: true, role: true, isBlocked: true, createdAt: true },
      }),
      prisma.payment.findMany({
        take: 5, orderBy: { createdAt: 'desc' },
        include: { user: { select: { email: true } } },
      }),
    ]);

    ok(res, {
      stats: {
        totalUsers, totalSeekers, totalEmployers,
        totalVacancies, activeVacancies, unmModeratedVacancies,
        totalApplications, totalRevenue: revenueAgg._sum.amount ?? 0,
      },
      recentUsers,
      recentPayments,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Users ────────────────────────────────────────────────────────────────────

export async function getUsers(req: AuthRequest, res: Response): Promise<void> {
  const { search = '', role, page = '1', limit = '20' } = req.query as Record<string, string>;
  const skip = (Number(page) - 1) * Number(limit);

  const where: Record<string, unknown> = {};
  if (role) where.role = role;
  if (search) where.email = { contains: search, mode: 'insensitive' };

  try {
    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where, skip, take: Number(limit),
        orderBy: { createdAt: 'desc' },
        select: {
          id: true, email: true, role: true, isBlocked: true, createdAt: true,
          seekerProfile: { select: { firstName: true, lastName: true, city: true } },
          employerProfile: { select: { companyName: true, isVerified: true } },
        },
      }),
      prisma.user.count({ where }),
    ]);
    ok(res, { users, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getUserDetail(req: AuthRequest, res: Response): Promise<void> {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      include: {
        seekerProfile: { include: { resumes: true, skillTests: true } },
        employerProfile: { include: { vacancies: { take: 5, orderBy: { createdAt: 'desc' } } } },
        payments: { take: 10, orderBy: { createdAt: 'desc' } },
      },
    });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }
    ok(res, user);
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function blockUser(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }

    await prisma.user.update({ where: { id }, data: { isBlocked: true } });

    if (user.role === 'EMPLOYER') {
      const employer = await prisma.employer.findUnique({ where: { userId: id } });
      if (employer) {
        await prisma.vacancy.updateMany({ where: { employerId: employer.id }, data: { isActive: false } });
      }
    }
    ok(res, { blocked: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function unblockUser(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }

    await prisma.user.update({ where: { id }, data: { isBlocked: false } });
    ok(res, { unblocked: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Vacancies ────────────────────────────────────────────────────────────────

export async function getVacancies(req: AuthRequest, res: Response): Promise<void> {
  const { moderated, page = '1', limit = '20' } = req.query as Record<string, string>;
  const skip = (Number(page) - 1) * Number(limit);

  const where: Record<string, unknown> = {};
  if (moderated !== undefined) where.isModerated = moderated === 'true';

  try {
    const [vacancies, total] = await Promise.all([
      prisma.vacancy.findMany({
        where, skip, take: Number(limit),
        orderBy: { createdAt: 'desc' },
        include: {
          employer: { select: { companyName: true, isVerified: true } },
          _count: { select: { applications: true } },
        },
      }),
      prisma.vacancy.count({ where }),
    ]);
    ok(res, { vacancies, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function moderateVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const vacancy = await prisma.vacancy.findUnique({ where: { id } });
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    await prisma.vacancy.update({ where: { id }, data: { isModerated: true, isActive: true } });
    ok(res, { moderated: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function rejectVacancy(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const vacancy = await prisma.vacancy.findUnique({ where: { id } });
    if (!vacancy) { fail(res, 'Вакансия не найдена', 404); return; }

    await prisma.vacancy.update({ where: { id }, data: { isActive: false, isModerated: true } });
    ok(res, { rejected: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Employers ────────────────────────────────────────────────────────────────

export async function getEmployers(req: AuthRequest, res: Response): Promise<void> {
  const { verified, page = '1', limit = '20' } = req.query as Record<string, string>;
  const skip = (Number(page) - 1) * Number(limit);

  const where: Record<string, unknown> = {};
  if (verified !== undefined) where.isVerified = verified === 'true';

  try {
    const [employers, total] = await Promise.all([
      prisma.employer.findMany({
        where, skip, take: Number(limit),
        orderBy: { id: 'desc' },
        include: {
          user: { select: { email: true, isBlocked: true, createdAt: true } },
          _count: { select: { vacancies: true } },
        },
      }),
      prisma.employer.count({ where }),
    ]);
    ok(res, { employers, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function verifyEmployer(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const employer = await prisma.employer.findUnique({ where: { id } });
    if (!employer) { fail(res, 'Работодатель не найден', 404); return; }

    await prisma.employer.update({ where: { id }, data: { isVerified: true } });
    ok(res, { verified: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Reports ──────────────────────────────────────────────────────────────────

export async function getReports(req: AuthRequest, res: Response): Promise<void> {
  const { resolved, page = '1', limit = '20' } = req.query as Record<string, string>;
  const skip = (Number(page) - 1) * Number(limit);

  const where: Record<string, unknown> = {};
  if (resolved !== undefined) where.isResolved = resolved === 'true';

  try {
    const [reports, total] = await Promise.all([
      prisma.report.findMany({
        where, skip, take: Number(limit),
        orderBy: { createdAt: 'desc' },
        include: { reporter: { select: { email: true } } },
      }),
      prisma.report.count({ where }),
    ]);
    ok(res, { reports, total, page: Number(page), pages: Math.ceil(total / Number(limit)) });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function resolveReport(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const report = await prisma.report.findUnique({ where: { id } });
    if (!report) { fail(res, 'Жалоба не найдена', 404); return; }

    await prisma.report.update({
      where: { id },
      data: { isResolved: true, resolvedAt: new Date() },
    });
    ok(res, { resolved: true });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// ─── Payments ─────────────────────────────────────────────────────────────────

export async function getPayments(req: AuthRequest, res: Response): Promise<void> {
  const { page = '1', limit = '20', status } = req.query as Record<string, string>;
  const skip = (Number(page) - 1) * Number(limit);

  const where: Record<string, unknown> = {};
  if (status) where.status = status;

  try {
    const [payments, total, revenueAgg] = await Promise.all([
      prisma.payment.findMany({
        where, skip, take: Number(limit),
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { email: true } } },
      }),
      prisma.payment.count({ where }),
      prisma.payment.aggregate({ _sum: { amount: true }, where: { status: 'PAID' } }),
    ]);
    ok(res, {
      payments, total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
      totalRevenue: revenueAgg._sum.amount ?? 0,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
