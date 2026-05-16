import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { uploadBuffer } from '../services/imagekit.service';
import prisma from '../lib/prisma';

export async function getProfile(req: AuthRequest, res: Response): Promise<void> {
  try {
    const profile = await prisma.employer.findUnique({
      where: { userId: req.user!.userId },
    });
    ok(res, { profile: profile ?? null });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function upsertProfile(req: AuthRequest, res: Response): Promise<void> {
  const { companyName, description, website, city } = req.body as {
    companyName: string;
    description?: string;
    website?: string;
    city?: string;
  };

  if (!companyName) { fail(res, 'companyName is required'); return; }

  const data = {
    companyName,
    description: description ?? null,
    website: website ?? null,
    city: city ?? null,
  };

  try {
    const profile = await prisma.employer.upsert({
      where: { userId: req.user!.userId },
      create: { userId: req.user!.userId, ...data },
      update: data,
    });
    ok(res, { profile });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function uploadLogo(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No file provided'); return; }

  try {
    const logoUrl = await uploadBuffer(
      req.file.buffer,
      req.file.mimetype,
      'ai-job-search/logos',
      `employer-${req.user!.userId}`
    );

    const profile = await prisma.employer.upsert({
      where: { userId: req.user!.userId },
      create: { userId: req.user!.userId, companyName: '', logoUrl },
      update: { logoUrl },
    });

    ok(res, { logoUrl: profile.logoUrl });
  } catch (e) {
    fail(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
