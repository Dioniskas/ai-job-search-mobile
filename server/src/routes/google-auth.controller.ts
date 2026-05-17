import { Request, Response } from 'express';
import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { ok, fail } from '../utils/response';

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// POST /api/auth/google/mobile
// Flutter отправляет idToken полученный от google_sign_in
export async function googleMobileAuth(req: Request, res: Response): Promise<void> {
  const { idToken } = req.body as { idToken?: string };
  if (!idToken) { fail(res, 'idToken is required'); return; }

  let payload;
  try {
    const ticket = await client.verifyIdToken({
      idToken,
      audience: [
        process.env.GOOGLE_CLIENT_ID!,
        // Android client id
        '310538934424-ob4g36nbd2p1fl7gqdkumm45j1kbhuh9.apps.googleusercontent.com',
      ],
    });
    payload = ticket.getPayload();
  } catch (e) {
    fail(res, 'Invalid Google token', 401);
    return;
  }

  if (!payload?.email) { fail(res, 'No email in Google token', 401); return; }

  const { email, name, picture, sub: googleId } = payload;

  // Find or create user
  let user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    // New user — create with SEEKER role by default
    user = await prisma.user.create({
      data: {
        email,
        password: `google_${googleId}`, // not used for login
        role: 'SEEKER',
      },
    });

    // Create seeker profile with Google data
    const nameParts = (name ?? '').split(' ');
    await prisma.seekerProfile.create({
      data: {
        userId: user.id,
        firstName: nameParts[0] ?? '',
        lastName: nameParts.slice(1).join(' ') ?? '',
        photoUrl: picture,
      },
    });
  }

  if (user.isBlocked) { fail(res, 'Аккаунт заблокирован', 403); return; }

  // Issue JWT tokens
  const accessToken = jwt.sign(
    { userId: user.id, role: user.role },
    process.env.JWT_SECRET!,
    { expiresIn: process.env.JWT_EXPIRES_IN ?? '15m' } as jwt.SignOptions,
  );

  const refreshToken = jwt.sign(
    { userId: user.id },
    process.env.JWT_REFRESH_SECRET!,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d' } as jwt.SignOptions,
  );

  // Save refresh token
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);
  await prisma.refreshToken.create({
    data: { userId: user.id, token: refreshToken, expiresAt },
  });

  ok(res, {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
    },
  });
}
