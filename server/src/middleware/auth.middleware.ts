import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AuthRequest, JwtPayload } from '../types';
import { fail } from '../utils/response';
import prisma from '../lib/prisma';

export async function authenticate(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    fail(res, 'Unauthorized', 401);
    return;
  }

  try {
    const token = header.split(' ')[1];
    const payload = jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload;

    const exists = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true },
    });
    if (!exists) {
      fail(res, 'Пользователь не найден — войдите снова', 401);
      return;
    }

    req.user = payload;
    next();
  } catch {
    fail(res, 'Invalid or expired token', 401);
  }
}

export function requireRole(...roles: Array<'SEEKER' | 'EMPLOYER' | 'ADMIN'>) {
  return (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      fail(res, 'Forbidden', 403);
      return;
    }
    next();
  };
}
