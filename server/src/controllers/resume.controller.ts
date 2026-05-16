import { Response } from 'express';
import pdfParse from 'pdf-parse';
import PDFDocument from 'pdfkit';
import * as fs from 'fs';
import * as nodePath from 'path';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import { uploadBuffer } from '../services/imagekit.service';
import prisma from '../lib/prisma';
import {
  improveResume,
  generateResumeFromForm,
  generateResumeFromTranscript,
  transcribeAudio,
  scoreResume,
  type ResumeContent,
} from '../services/ai/groq.service';

// ── Font discovery for Cyrillic support ───────────────────────────────────────
function findCyrillicFont(): string | undefined {
  const candidates = [
    nodePath.join(process.cwd(), 'fonts', 'FreeSans.ttf'),
    'C:\\Windows\\Fonts\\arial.ttf',
    'C:\\Windows\\Fonts\\times.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ];
  return candidates.find(p => fs.existsSync(p));
}

async function getOrCreateProfile(userId: string) {
  const existing = await prisma.seekerProfile.findUnique({ where: { userId } });
  if (existing) return existing;

  const user = await prisma.user.findUnique({ where: { id: userId }, select: { id: true } });
  if (!user) return null;

  return prisma.seekerProfile.create({
    data: { userId, firstName: '', lastName: '' },
  });
}

function resumeTitle(content: ResumeContent, fallback = 'Моё резюме') {
  return content.title || fallback;
}

// GET /api/resume
export async function getResumes(req: AuthRequest, res: Response): Promise<void> {
  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) {
    ok(res, { data: [], total: 0, page: 1, totalPages: 0 });
    return;
  }

  const pageStr  = req.query['page']  as string | undefined;
  const limitStr = req.query['limit'] as string | undefined;
  const page     = Math.max(1, parseInt(pageStr  ?? '1',  10));
  const limit    = Math.min(50, Math.max(1, parseInt(limitStr ?? '20', 10)));
  const skip     = (page - 1) * limit;

  const [resumes, total] = await Promise.all([
    prisma.resume.findMany({
      where: { seekerId: profile.id },
      orderBy: { updatedAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.resume.count({ where: { seekerId: profile.id } }),
  ]);

  ok(res, { data: resumes, total, page, totalPages: Math.ceil(total / limit) });
}

// POST /api/resume/upload — Way 1: PDF → extract text → save as-is
export async function uploadPdf(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No PDF file provided'); return; }

  const profile = await getOrCreateProfile(req.user!.userId);
  if (!profile) { fail(res, 'Пользователь не найден', 401); return; }

  const [pdfUrl, parsed] = await Promise.all([
    uploadBuffer(req.file.buffer, req.file.mimetype, 'ai-job-search/resumes', `resume-${profile.id}-${Date.now()}`),
    pdfParse(req.file.buffer),
  ]);

  const rawText = parsed.text.trim();
  const content: ResumeContent = {
    title: 'Резюме из PDF',
    summary: '',
    experience: rawText,
    education: '',
    skills: [],
    rawText,
  };

  const resume = await prisma.resume.create({
    data: {
      seekerId: profile.id,
      title: content.title,
      content: content as object,
      pdfUrl,
      isAiGenerated: false,
      skills: [],
      experience: rawText.slice(0, 500),
    },
  });

  ok(res, { resume }, 201);
}

// POST /api/resume/improve — Way 2: PDF → AI improve → save
export async function improvePdf(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No PDF file provided'); return; }

  const profile = await getOrCreateProfile(req.user!.userId);
  if (!profile) { fail(res, 'Пользователь не найден', 401); return; }

  const [pdfUrl, parsed] = await Promise.all([
    uploadBuffer(req.file.buffer, req.file.mimetype, 'ai-job-search/resumes', `resume-${profile.id}-${Date.now()}`),
    pdfParse(req.file.buffer),
  ]);

  const rawText = parsed.text.trim();
  if (!rawText) { fail(res, 'Could not extract text from PDF'); return; }

  let content;
  try {
    content = await improveResume(rawText);
  } catch (e) {
    fail(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
    return;
  }

  const resume = await prisma.resume.create({
    data: {
      seekerId: profile.id,
      title: resumeTitle(content, 'Улучшенное резюме'),
      content: content as object,
      pdfUrl,
      isAiGenerated: true,
      skills: content.skills,
      experience: content.experience.slice(0, 500),
    },
  });

  ok(res, { resume }, 201);
}

// POST /api/resume/generate/text — Way 3: form → GPT-4o → save
export async function generateFromText(req: AuthRequest, res: Response): Promise<void> {
  const { name, age, experience, skills, about } = req.body as {
    name: string; age?: string; experience: string; skills: string; about?: string;
  };

  if (!name || !experience || !skills) {
    fail(res, 'name, experience and skills are required');
    return;
  }

  const profile = await getOrCreateProfile(req.user!.userId);
  if (!profile) { fail(res, 'Пользователь не найден', 401); return; }

  let content;
  try {
    content = await generateResumeFromForm({ name, age, experience, skills, about });
  } catch (e) {
    fail(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
    return;
  }

  const resume = await prisma.resume.create({
    data: {
      seekerId: profile.id,
      title: resumeTitle(content, 'Резюме из формы'),
      content: content as object,
      isAiGenerated: true,
      skills: content.skills,
      experience: content.experience.slice(0, 500),
    },
  });

  ok(res, { resume }, 201);
}

// POST /api/resume/generate/voice — Way 4: audio → Whisper → GPT-4o → save
export async function generateFromVoice(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No audio file provided'); return; }

  const profile = await getOrCreateProfile(req.user!.userId);
  if (!profile) { fail(res, 'Пользователь не найден', 401); return; }

  let transcript: string;
  try {
    transcript = await transcribeAudio(req.file.buffer, req.file.mimetype);
  } catch (e) {
    fail(res, `Transcription error: ${e instanceof Error ? e.message : 'unknown'}`);
    return;
  }
  if (!transcript.trim()) { fail(res, 'Could not transcribe audio'); return; }

  let content;
  try {
    content = await generateResumeFromTranscript(transcript);
  } catch (e) {
    fail(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
    return;
  }

  const resume = await prisma.resume.create({
    data: {
      seekerId: profile.id,
      title: resumeTitle(content, 'Резюме из голоса'),
      content: { ...content, transcript } as object,
      isAiGenerated: true,
      skills: content.skills,
      experience: content.experience.slice(0, 500),
    },
  });

  ok(res, { resume }, 201);
}

// PUT /api/resume/:id
export async function updateResume(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  const { title, content, skills, experience } = req.body as {
    title?: string;
    content?: ResumeContent;
    skills?: string[];
    experience?: string;
  };

  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  const updated = await prisma.resume.update({
    where: { id },
    data: {
      ...(title    && { title }),
      ...(content  && { content: content as object }),
      ...(skills   && { skills }),
      ...(experience !== undefined && { experience }),
    },
  });

  ok(res, { resume: updated });
}

// PUT /api/resume/:id/main — mark one resume as main, clear flag on others
export async function setMainResume(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;

  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  await prisma.$transaction([
    prisma.resume.updateMany({
      where: { seekerId: profile.id },
      data: { isMain: false },
    }),
    prisma.resume.update({
      where: { id },
      data: { isMain: true },
    }),
  ]);

  ok(res, { success: true });
}

// POST /api/resume/:id/score
export async function scoreResumeCtrl(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;

  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  let scoreResult;
  try {
    const content = existing.content as unknown as ResumeContent;
    scoreResult = await scoreResume(content);
  } catch (e) {
    fail(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
    return;
  }

  const existingContent = (existing.content as Record<string, unknown>) ?? {};
  const updatedContent: Record<string, unknown> = {
    ...existingContent,
    aiScore: scoreResult.score,
    aiScoreStrengths: scoreResult.strengths,
    aiScoreImprovements: scoreResult.improvements,
    aiScoreSummary: scoreResult.summary,
  };

  const resume = await prisma.resume.update({
    where: { id },
    data: { content: updatedContent as object },
  });

  ok(res, {
    resume: {
      ...resume,
      aiScore: scoreResult.score,
      aiScoreDetails: scoreResult,
    },
  });
}

// GET /api/resume/:id/pdf
export async function generateResumePdf(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;

  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const resume = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!resume) { fail(res, 'Resume not found', 404); return; }

  const content = (resume.content ?? {}) as Record<string, unknown>;

  try {
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    const fontPath = findCyrillicFont();

    if (fontPath) {
      doc.registerFont('Main', fontPath);
      doc.font('Main');
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="resume-${id}.pdf"`,
    );
    doc.pipe(res);

    // ── Header ────────────────────────────────────────────────────────────────
    doc.fontSize(20).text(resume.title, { align: 'center' });
    doc.moveDown(0.5);

    const seekerName = `${profile.firstName} ${profile.lastName}`.trim();
    if (seekerName) {
      doc.fontSize(13).text(seekerName, { align: 'center' });
      doc.moveDown(0.3);
    }
    if (profile.city) {
      doc.fontSize(11).fillColor('#64748B').text(profile.city, { align: 'center' });
    }
    if (profile.phone) {
      doc.fontSize(11).fillColor('#64748B').text(profile.phone, { align: 'center' });
    }
    doc.fillColor('#000000');
    doc.moveDown(0.8);

    // ── Divider ───────────────────────────────────────────────────────────────
    doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#CBD5E1').stroke();
    doc.moveDown(0.6);

    // ── Section helper ────────────────────────────────────────────────────────
    function section(title: string, body: string): void {
      doc
        .fontSize(12)
        .fillColor('#1E3A8A')
        .text(title.toUpperCase(), { underline: false });
      doc
        .fontSize(10)
        .fillColor('#0F172A')
        .text(body, { lineGap: 3 });
      doc.moveDown(0.7);
    }

    const summary    = (content['summary']    as string | undefined) ?? '';
    const experience = (content['experience'] as string | undefined) ?? '';
    const education  = (content['education']  as string | undefined) ?? '';
    const languages  = (content['languages']  as string | undefined) ?? '';
    const additional = (content['additional'] as string | undefined) ?? '';
    const rawText    = (content['rawText']    as string | undefined) ?? '';

    if (summary)    section('О себе',        summary);
    if (resume.skills.length > 0) {
      section('Навыки', resume.skills.join(' • '));
    }
    if (experience) section('Опыт работы',   experience);
    if (education)  section('Образование',   education);
    if (languages)  section('Языки',         languages);
    if (additional) section('Дополнительно', additional);
    if (!summary && !experience && rawText) {
      section('Текст резюме', rawText.slice(0, 4000));
    }

    doc.end();
  } catch (e) {
    // Headers not sent yet only if doc.pipe didn't start — safest to just log
    if (!res.headersSent) {
      fail(res, `PDF generation error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
  }
}

// DELETE /api/resume/:id
export async function deleteResume(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;

  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  await prisma.resume.delete({ where: { id } });
  ok(res, { deleted: true });
}
