import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { uploadBuffer } from '../services/imagekit.service';
import prisma from '../lib/prisma';

export async function getProfile(req: AuthRequest, res: Response): Promise<void> {
  try {
    const profile = await prisma.seekerProfile.findUnique({
      where: { userId: req.user!.userId },
    });
    ok(res, { profile: profile ?? null });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function upsertProfile(req: AuthRequest, res: Response): Promise<void> {
  const { firstName, lastName, middleName, age, phone, city, about, searchStatus } = req.body as {
    firstName?: string;
    lastName?: string;
    middleName?: string;
    age?: string;
    phone?: string;
    city?: string;
    about?: string;
    searchStatus?: string;
  };

  const allowedStatuses = ['ACTIVE', 'OPEN', 'NOT_LOOKING'];

  // Partial update: only include fields that were actually sent
  const updateData: Record<string, unknown> = {};
  if (firstName !== undefined) updateData['firstName'] = firstName;
  if (lastName  !== undefined) updateData['lastName']  = lastName;
  if (middleName !== undefined) updateData['middleName'] = middleName ?? null;
  if (age       !== undefined) updateData['age']       = age ? parseInt(age, 10) : null;
  if (phone     !== undefined) updateData['phone']     = phone ?? null;
  if (city      !== undefined) updateData['city']      = city ?? null;
  if (about     !== undefined) updateData['about']     = about ?? null;
  if (searchStatus && allowedStatuses.includes(searchStatus)) {
    updateData['searchStatus'] = searchStatus;
  }

  try {
    const profile = await prisma.seekerProfile.upsert({
      where: { userId: req.user!.userId },
      create: { userId: req.user!.userId, firstName: firstName ?? '', lastName: lastName ?? '', ...updateData },
      update: updateData,
    });
    ok(res, { profile });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function uploadPhoto(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No file provided'); return; }

  try {
    const photoUrl = await uploadBuffer(
      req.file.buffer,
      req.file.mimetype,
      'ai-job-search/avatars',
      `seeker-${req.user!.userId}`
    );

    const profile = await prisma.seekerProfile.upsert({
      where: { userId: req.user!.userId },
      create: { userId: req.user!.userId, firstName: '', lastName: '', photoUrl },
      update: { photoUrl },
    });

    ok(res, { photoUrl: profile.photoUrl });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function setVisibility(req: AuthRequest, res: Response): Promise<void> {
  const { isVisible } = req.body as { isVisible: boolean };

  if (typeof isVisible !== 'boolean') {
    fail(res, 'isVisible must be a boolean');
    return;
  }

  try {
    const profile = await prisma.seekerProfile.upsert({
      where: { userId: req.user!.userId },
      create: { userId: req.user!.userId, firstName: '', lastName: '', isVisible },
      update: { isVisible },
    });
    ok(res, { isVisible: profile.isVisible });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
