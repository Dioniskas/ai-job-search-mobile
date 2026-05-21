import { Response } from 'express';
import pdfParse from 'pdf-parse';
import PDFDocument from 'pdfkit';
import path from 'path';
import fs from 'fs';
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

export function initFonts(): string | null {
  const fontPath = path.join(process.cwd(), 'fonts', 'DejaVuSans.ttf');
  if (fs.existsSync(fontPath)) {
    return fontPath;
  }
  console.error('[resume] DejaVuSans.ttf not found at', fontPath, '— PDF output will use default font');
  return null;
}

async function getOrCreateProfile(userId: string) {
  const existing = await prisma.seekerProfile.findUnique({ where: { userId } });
  if (existing) return existing;
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
    ok(res, { resumes: [] });
    return;
  }

  const resumes = await prisma.resume.findMany({
    where: { seekerId: profile.id },
    orderBy: { updatedAt: 'desc' },
  });
  ok(res, { resumes });
}

// POST /api/resume/upload — Way 1: PDF → extract text → save as-is
export async function uploadPdf(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No PDF file provided'); return; }

  const profile = await getOrCreateProfile(req.user!.userId);

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

  // Persist score in content JSON
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

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  const content = existing.content as Record<string, unknown>;
  const fontPath = initFonts();

  const doc = new PDFDocument({ margin: 50 });

  doc.on('error', (err) => {
    console.error('[pdf] stream error:', err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'PDF generation failed' });
    }
  });

  res.on('close', () => {
    doc.end();
  });

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="resume-${id}.pdf"`);

  doc.pipe(res);

  if (fontPath) {
    doc.registerFont('DejaVu', fontPath);
    doc.font('DejaVu');
  }

  doc.fontSize(20).text(existing.title || 'Резюме', { align: 'center' });
  doc.moveDown();

  if (content.summary) {
    doc.fontSize(12).text(String(content.summary));
    doc.moveDown();
  }

  if (content.experience) {
    doc.fontSize(14).text('Опыт работы');
    doc.fontSize(11).text(String(content.experience));
    doc.moveDown();
  }

  if (content.education) {
    doc.fontSize(14).text('Образование');
    doc.fontSize(11).text(String(content.education));
    doc.moveDown();
  }

  if (Array.isArray(content.skills) && content.skills.length > 0) {
    doc.fontSize(14).text('Навыки');
    doc.fontSize(11).text((content.skills as string[]).join(', '));
    doc.moveDown();
  }

  doc.end();
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
