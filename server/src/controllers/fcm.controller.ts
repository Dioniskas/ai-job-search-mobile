import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

// POST /api/users/fcm-token
export async function saveFcmToken(req: AuthRequest, res: Response): Promise<void> {
  const { token } = req.body as { token?: string };
  if (!token) { fail(res, 'token is required'); return; }

  try {
    await prisma.user.update({
      where: { id: req.user!.userId },
      data: { fcmToken: token },
    });
    ok(res, { success: true });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

// DELETE /api/users/fcm-token  — call on logout
export async function deleteFcmToken(req: AuthRequest, res: Response): Promise<void> {
  try {
    await prisma.user.update({
      where: { id: req.user!.userId },
      data: { fcmToken: null },
    });
    ok(res, { success: true });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
