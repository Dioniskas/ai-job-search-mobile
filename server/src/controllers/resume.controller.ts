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

function findCyrillicFont(): string | null {
  const candidates = [
    path.join(process.cwd(), 'fonts', 'DejaVuSans.ttf'),
    path.join(process.cwd(), 'fonts', 'Arial.ttf'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

// GET /api/resume/:id/pdf
export async function generateResumePdf(req: AuthRequest, res: Response): Promise<void> {
  const { id } = req.params;
  try {
    const profile = await prisma.seekerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!profile) { fail(res, 'Profile not found', 404); return; }
    const resume = await prisma.resume.findFirst({ where: { id, seekerId: profile.id } });
    if (!resume) { fail(res, 'Resume not found', 404); return; }
    const user = await prisma.user.findUnique({ where: { id: req.user!.userId }, select: { email: true } });
    const content = (resume.content ?? {}) as Record<string, unknown>;

    let photoBuffer: Buffer | null = null;
    if (resume.photoUrl) {
      try {
        const resp = await fetch(resume.photoUrl);
        if (resp.ok) photoBuffer = Buffer.from(await resp.arrayBuffer());
      } catch { /* skip */ }
    }

    const PDFDocument = require('pdfkit');
    const doc = new PDFDocument({ margin: 0, size: 'A4', bufferPages: true });
    const fontPath = findCyrillicFont();
    if (fontPath) doc.registerFont('Cv', fontPath);
    const setFont = () => { if (fontPath) doc.font('Cv'); return doc; };

    const chunks: Buffer[] = [];
    doc.on('data', (chunk: Buffer) => chunks.push(chunk));

    await new Promise<void>((resolve, reject) => {
      doc.on('end', resolve);
      doc.on('error', reject);

      const PAGE_W = 595.28, MARGIN = 44, CONTENT_W = PAGE_W - MARGIN * 2;
      const PRIMARY = '#2563EB', DARK = '#0F172A', MID = '#334155';
      const MUTED = '#64748B', DIVIDER = '#E2E8F0', SECTION_LABEL = '#94A3B8';
      const PHOTO_SIZE = 88, HEADER_Y = 28;
      const HAS_PHOTO = !!photoBuffer;
      const TEXT_X = HAS_PHOTO ? MARGIN + PHOTO_SIZE + 18 : MARGIN;
      const TEXT_W = HAS_PHOTO ? CONTENT_W - PHOTO_SIZE - 18 : CONTENT_W;

      if (HAS_PHOTO && photoBuffer) {
        const cx = MARGIN + PHOTO_SIZE / 2, cy = HEADER_Y + PHOTO_SIZE / 2;
        doc.save().circle(cx, cy, PHOTO_SIZE / 2).clip();
        doc.image(photoBuffer, MARGIN, HEADER_Y, { width: PHOTO_SIZE, height: PHOTO_SIZE });
        doc.restore().circle(cx, cy, PHOTO_SIZE / 2).lineWidth(2.5).strokeColor(PRIMARY).stroke();
      }

      let textY = HEADER_Y + 2;
      const seekerName = `${profile!.firstName ?? ''} ${profile!.lastName ?? ''}`.trim();
      if (seekerName) { setFont().fontSize(20).fillColor(DARK).text(seekerName, TEXT_X, textY, { width: TEXT_W, lineBreak: false }); textY += 27; }
      setFont().fontSize(12).fillColor(PRIMARY).text(resume!.title, TEXT_X, textY, { width: TEXT_W, lineBreak: false }); textY += 19;

      const phone = (content['phone'] as string) || profile!.phone || '';
      const city = (content['city'] as string) || profile!.city || '';
      const email = (content['email'] as string) || user?.email || '';
      const contacts = [phone, city, email].filter(Boolean).join('   |   ');
      if (contacts) { setFont().fontSize(9).fillColor(MUTED).text(contacts, TEXT_X, textY, { width: TEXT_W, lineBreak: false }); textY += 15; }

      const headerEndY = Math.max(textY + 10, HEADER_Y + PHOTO_SIZE + 14);
      doc.moveTo(MARGIN, headerEndY).lineTo(PAGE_W - MARGIN, headerEndY).lineWidth(0.75).strokeColor(DIVIDER).stroke();
      let bodyY = headerEndY + 15;

      const sectionTitle = (title: string) => {
        setFont().fontSize(9).fillColor(SECTION_LABEL).text(title.toUpperCase(), MARGIN, bodyY, { width: CONTENT_W, lineBreak: false });
        bodyY += 13;
        doc.moveTo(MARGIN, bodyY - 2).lineTo(PAGE_W - MARGIN, bodyY - 2).lineWidth(0.5).strokeColor(DIVIDER).stroke();
        bodyY += 6;
      };
      const sectionBody = (text: string) => {
        setFont().fontSize(10).fillColor(MID).text(text, MARGIN, bodyY, { width: CONTENT_W, lineGap: 2 });
        bodyY = doc.y + 10;
      };
      const sectionGap = () => {
        doc.moveTo(MARGIN, bodyY).lineTo(PAGE_W - MARGIN, bodyY).lineWidth(0.5).strokeColor(DIVIDER).stroke();
        bodyY += 13;
      };

      const summary = (content['summary'] as string) ?? '';
      const experience = (content['experience'] as string) || resume!.experience || '';
      const education = (content['education'] as string) ?? '';
      const languages = (content['languages'] as string) ?? '';

      if (summary) { sectionTitle('О себе'); sectionBody(summary); sectionGap(); }
      if (experience) { sectionTitle('Опыт работы'); sectionBody(experience); sectionGap(); }
      if (education) { sectionTitle('Образование'); sectionBody(education); sectionGap(); }

      if (resume!.skills.length > 0) {
        sectionTitle('Навыки');
        const TAG_H = 20, PAD_H = 10, PAD_V = 4;
        let tagX = MARGIN, tagY = bodyY;
        setFont().fontSize(9);
        for (const skill of resume!.skills) {
          const tw = doc.widthOfString(skill) + PAD_H * 2;
          if (tagX + tw > PAGE_W - MARGIN) { tagX = MARGIN; tagY += TAG_H + 6; }
          doc.roundedRect(tagX, tagY, tw, TAG_H, 10).fill('#DBEAFE');
          setFont().fontSize(9).fillColor('#1E40AF').text(skill, tagX + PAD_H, tagY + PAD_V, { width: tw - PAD_H * 2, lineBreak: false });
          tagX += tw + 8;
        }
        bodyY = tagY + TAG_H + 13;
        sectionGap();
      }

      if (languages) { sectionTitle('Языки'); sectionBody(languages); }

      doc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="resume-${id}.pdf"`);
    res.send(pdfBuffer);
  } catch (e) {
    if (!res.headersSent) fail(res, `PDF generation error: ${e instanceof Error ? e.message : 'unknown'}`);
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
