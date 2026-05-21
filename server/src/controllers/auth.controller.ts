import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Role } from '@prisma/client';
import { AuthRequest, JwtPayload } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';

function signToken(payload: JwtPayload): string {
  return jwt.sign(payload, process.env.JWT_SECRET as string, {
    expiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  } as jwt.SignOptions);
}

export async function register(req: Request, res: Response): Promise<void> {
  const { email, password, role } = req.body as {
    email: string;
    password: string;
    role: Role;
  };

  if (!email || !password || !role) {
    fail(res, 'email, password and role are required');
    return;
  }

  if (!Object.values(Role).includes(role)) {
    fail(res, 'role must be SEEKER or EMPLOYER');
    return;
  }

  if (password.length < 6) {
    fail(res, 'password must be at least 6 characters');
    return;
  }

  const exists = await prisma.user.findUnique({ where: { email } });
  if (exists) {
    fail(res, 'Email already in use', 409);
    return;
  }

  const hashed = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: { email, password: hashed, role },
  });

  const token = signToken({ userId: user.id, email: user.email, role: user.role });
  ok(res, { token, user: { id: user.id, email: user.email, role: user.role } }, 201);
}

export async function login(req: Request, res: Response): Promise<void> {
  const { email, password } = req.body as { email: string; password: string };

  if (!email || !password) {
    fail(res, 'email and password are required');
    return;
  }

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await bcrypt.compare(password, user.password))) {
    fail(res, 'Invalid credentials', 401);
    return;
  }

  const token = signToken({ userId: user.id, email: user.email, role: user.role });
  ok(res, { token, user: { id: user.id, email: user.email, role: user.role } });
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

    if (!user) { fail(res, 'User not found', 404); return; }
    ok(res, { user });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
