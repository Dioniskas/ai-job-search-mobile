import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

export interface EmailNotificationSettings {
  welcome:            boolean;
  newApplication:     boolean;
  applicationStatus:  boolean;
  interview:          boolean;
  passwordReset:      boolean;
}

const DEFAULT_SETTINGS: EmailNotificationSettings = {
  welcome:           true,
  newApplication:    true,
  applicationStatus: true,
  interview:         true,
  passwordReset:     true,
};

export function getEmailPrefs(raw: unknown): EmailNotificationSettings {
  if (!raw || typeof raw !== 'object') return { ...DEFAULT_SETTINGS };
  const s = raw as Partial<EmailNotificationSettings>;
  return {
    welcome:           s.welcome           ?? true,
    newApplication:    s.newApplication    ?? true,
    applicationStatus: s.applicationStatus ?? true,
    interview:         s.interview         ?? true,
    passwordReset:     s.passwordReset     ?? true,
  };
}

// GET /api/users/email-notifications
export async function getEmailNotifications(req: AuthRequest, res: Response): Promise<void> {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: { emailNotifications: true },
    });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }
    ok(res, { settings: getEmailPrefs(user.emailNotifications) });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// PUT /api/users/email-notifications
export async function updateEmailNotifications(req: AuthRequest, res: Response): Promise<void> {
  const body = req.body as Partial<EmailNotificationSettings>;
  const allowed = ['welcome', 'newApplication', 'applicationStatus', 'interview', 'passwordReset'];

  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: { emailNotifications: true },
    });
    if (!user) { fail(res, 'Пользователь не найден', 404); return; }

    const current = getEmailPrefs(user.emailNotifications);
    const updated: Record<string, boolean> = { ...current };

    for (const key of allowed) {
      const val = body[key as keyof EmailNotificationSettings];
      if (typeof val === 'boolean') updated[key] = val;
    }

    await prisma.user.update({
      where: { id: req.user!.userId },
      data:  { emailNotifications: updated },
    });

    ok(res, { settings: updated });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
