import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Role } from '@prisma/client';
import { AuthRequest, JwtPayload } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import { sendWelcomeEmail, sendPasswordResetEmail } from '../services/email.service';
import { getEmailPrefs } from '../controllers/email-notifications.controller';

function signAccessToken(payload: JwtPayload): string {
  return jwt.sign(payload, process.env.JWT_SECRET as string, {
    expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
  } as jwt.SignOptions);
}

function generateRefreshToken(): string {
  return crypto.randomBytes(64).toString('hex');
}

async function saveRefreshToken(userId: string, token: string): Promise<void> {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);
  await prisma.refreshToken.create({ data: { userId, token, expiresAt } });
}

function buildAuthResponse(userId: string, email: string, role: Role) {
  const accessToken = signAccessToken({ userId, email, role });
  const refreshToken = generateRefreshToken();
  return { accessToken, refreshToken };
}

export async function register(req: Request, res: Response): Promise<void> {
  const { email, password, role, firstName } = req.body as {
    email: string;
    password: string;
    role: Role;
    firstName?: string;
  };

  const exists = await prisma.user.findUnique({ where: { email } });
  if (exists) { fail(res, 'Email уже используется', 409); return; }

  const hashed = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({ data: { email, password: hashed, role } });

  const { accessToken, refreshToken } = buildAuthResponse(user.id, user.email, user.role);
  await saveRefreshToken(user.id, refreshToken);

  // Welcome email (fire-and-forget, non-blocking)
  const name = firstName?.trim() || email.split('@')[0];
  sendWelcomeEmail(email, name).catch(() => {});

  ok(res, {
    accessToken,
    refreshToken,
    user: { id: user.id, email: user.email, role: user.role },
  }, 201);
}

export async function login(req: Request, res: Response): Promise<void> {
  const { email, password } = req.body as { email: string; password: string };

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await bcrypt.compare(password, user.password))) {
    fail(res, 'Неверный email или пароль', 401);
    return;
  }
  if (user.isBlocked) {
    fail(res, 'Аккаунт заблокирован. Обратитесь в поддержку.', 401);
    return;
  }

  const { accessToken, refreshToken } = buildAuthResponse(user.id, user.email, user.role);
  await saveRefreshToken(user.id, refreshToken);

  ok(res, {
    accessToken,
    refreshToken,
    user: { id: user.id, email: user.email, role: user.role },
  });
}

export async function refresh(req: Request, res: Response): Promise<void> {
  const { refreshToken } = req.body as { refreshToken: string };

  try {
    const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.expiresAt < new Date()) {
      if (stored) await prisma.refreshToken.delete({ where: { token: refreshToken } });
      fail(res, 'Refresh token недействителен или истёк', 401);
      return;
    }

    const user = await prisma.user.findUnique({ where: { id: stored.userId } });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }

    await prisma.refreshToken.delete({ where: { token: refreshToken } });

    const { accessToken, refreshToken: newRefreshToken } = buildAuthResponse(user.id, user.email, user.role);
    await saveRefreshToken(user.id, newRefreshToken);

    ok(res, { accessToken, refreshToken: newRefreshToken });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function logout(req: AuthRequest, res: Response): Promise<void> {
  const { refreshToken } = req.body as { refreshToken?: string };
  if (refreshToken) {
    await prisma.refreshToken.deleteMany({ where: { token: refreshToken } }).catch(() => {});
  }
  ok(res, { loggedOut: true });
}

export async function me(req: AuthRequest, res: Response): Promise<void> {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: {
        id: true,
        email: true,
        role: true,
        createdAt: true,
        seekerProfile: {
          select: { firstName: true, lastName: true, photoUrl: true, city: true },
        },
        employerProfile: {
          select: { companyName: true, logoUrl: true, city: true },
        },
      },
    });

    if (!user) { fail(res, 'Пользователь не найден', 404); return; }
    ok(res, { user });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/auth/forgot-password
export async function forgotPassword(req: Request, res: Response): Promise<void> {
  const { email } = req.body as { email: string };
  if (!email) { fail(res, 'Email обязателен'); return; }

  try {
    const user = await prisma.user.findUnique({ where: { email } });

    // Always return success to avoid user enumeration
    if (!user) { ok(res, { message: 'Если email существует, письмо отправлено' }); return; }

    const prefs = getEmailPrefs(user.emailNotifications);
    if (!prefs.passwordReset) {
      ok(res, { message: 'Если email существует, письмо отправлено' });
      return;
    }

    const token    = crypto.randomBytes(32).toString('hex');
    const expires  = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await prisma.user.update({
      where: { id: user.id },
      data:  { passwordResetToken: token, passwordResetExpires: expires },
    });

    sendPasswordResetEmail(email, token).catch(() => {});

    ok(res, { message: 'Если email существует, письмо отправлено' });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// POST /api/auth/reset-password
export async function resetPassword(req: Request, res: Response): Promise<void> {
  const { token, password } = req.body as { token: string; password: string };
  if (!token || !password) { fail(res, 'token и password обязательны'); return; }
  if (password.length < 6) { fail(res, 'Пароль минимум 6 символов'); return; }

  try {
    const user = await prisma.user.findFirst({
      where: {
        passwordResetToken:   token,
        passwordResetExpires: { gt: new Date() },
      },
    });

    if (!user) { fail(res, 'Токен недействителен или истёк', 400); return; }

    const hashed = await bcrypt.hash(password, 10);

    await prisma.user.update({
      where: { id: user.id },
      data:  {
        password:             hashed,
        passwordResetToken:   null,
        passwordResetExpires: null,
      },
    });

    // Invalidate all refresh tokens for security
    await prisma.refreshToken.deleteMany({ where: { userId: user.id } });

    ok(res, { message: 'Пароль успешно изменён' });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
