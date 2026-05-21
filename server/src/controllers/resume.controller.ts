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
const DEJAVU_LOCAL = nodePath.join(__dirname, '../../fonts/DejaVuSans.ttf');

function findCyrillicFont(): string | undefined {
  const candidates = [
    DEJAVU_LOCAL,
    nodePath.join(process.cwd(), 'fonts', 'FreeSans.ttf'),
    // Railway / Debian
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
    '/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
    '/usr/share/fonts/truetype/open-sans/OpenSans-Regular.ttf',
    // macOS
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/Library/Fonts/Arial.ttf',
    // Windows
    'C:\\Windows\\Fonts\\arial.ttf',
    'C:\\Windows\\Fonts\\times.ttf',
  ];
  return candidates.find(p => fs.existsSync(p));
}

export function initFonts(): void {
  if (fs.existsSync(DEJAVU_LOCAL)) return;
  if (findCyrillicFont()) return;
  console.error('[fonts] DejaVuSans.ttf not found at', DEJAVU_LOCAL, '— PDF will render without Cyrillic font');
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

  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    select: { email: true },
  });

  const content = (resume.content ?? {}) as Record<string, unknown>;

  // Download candidate photo if available
  let photoBuffer: Buffer | null = null;
  if (resume.photoUrl) {
    try {
      const resp = await fetch(resume.photoUrl);
      if (resp.ok) photoBuffer = Buffer.from(await resp.arrayBuffer());
    } catch { /* photo unavailable — skip */ }
  }

  try {
    const doc = new PDFDocument({ margin: 0, size: 'A4' });
    const fontPath = findCyrillicFont();
    if (fontPath) doc.registerFont('Cv', fontPath);
    const setFont = () => { if (fontPath) doc.font('Cv'); return doc; };

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="resume-${id}.pdf"`);
    doc.pipe(res);

    const PAGE_W    = 595.28;
    const MARGIN    = 44;
    const CONTENT_W = PAGE_W - MARGIN * 2;
    const PRIMARY   = '#2563EB';
    const DARK      = '#0F172A';
    const MID       = '#334155';
    const MUTED     = '#64748B';
    const DIVIDER   = '#E2E8F0';
    const SECTION_LABEL = '#94A3B8';

    // ── Header: photo left | name+title+contacts right ────────────────────────
    const PHOTO_SIZE = 88;
    const HEADER_Y   = 28;
    const HAS_PHOTO  = !!photoBuffer;
    const TEXT_X     = HAS_PHOTO ? MARGIN + PHOTO_SIZE + 18 : MARGIN;
    const TEXT_W     = HAS_PHOTO ? CONTENT_W - PHOTO_SIZE - 18 : CONTENT_W;

    if (HAS_PHOTO && photoBuffer) {
      const cx = MARGIN + PHOTO_SIZE / 2;
      const cy = HEADER_Y + PHOTO_SIZE / 2;
      doc.save();
      doc.circle(cx, cy, PHOTO_SIZE / 2).clip();
      doc.image(photoBuffer, MARGIN, HEADER_Y, { width: PHOTO_SIZE, height: PHOTO_SIZE });
      doc.restore();
      doc.circle(cx, cy, PHOTO_SIZE / 2).lineWidth(2.5).strokeColor(PRIMARY).stroke();
    }

    let textY = HEADER_Y + 2;
    const seekerName = `${profile.firstName ?? ''} ${profile.lastName ?? ''}`.trim();

    if (seekerName) {
      setFont().fontSize(20).fillColor(DARK)
        .text(seekerName, TEXT_X, textY, { width: TEXT_W, lineBreak: false });
      textY += 27;
    }

    setFont().fontSize(12).fillColor(PRIMARY)
      .text(resume.title, TEXT_X, textY, { width: TEXT_W, lineBreak: false });
    textY += 19;

    const phone = (content['phone'] as string | undefined) || profile.phone || '';
    const city  = (content['city']  as string | undefined) || profile.city  || '';
    const email = (content['email'] as string | undefined) || user?.email   || '';
    const contactParts: string[] = [];
    if (phone) contactParts.push(phone);
    if (city)  contactParts.push(city);
    if (email) contactParts.push(email);
    if (contactParts.length > 0) {
      setFont().fontSize(9).fillColor(MUTED)
        .text(contactParts.join('   |   '), TEXT_X, textY, { width: TEXT_W, lineBreak: false });
      textY += 15;
    }

    const headerEndY = Math.max(textY + 10, HEADER_Y + PHOTO_SIZE + 14);
    doc.moveTo(MARGIN, headerEndY).lineTo(PAGE_W - MARGIN, headerEndY)
      .lineWidth(0.75).strokeColor(DIVIDER).stroke();

    let bodyY = headerEndY + 15;

    // ── Section helpers ───────────────────────────────────────────────────────
    function sectionTitle(title: string): void {
      setFont().fontSize(9).fillColor(SECTION_LABEL)
        .text(title.toUpperCase(), MARGIN, bodyY, { width: CONTENT_W, lineBreak: false });
      bodyY += 13;
      doc.moveTo(MARGIN, bodyY - 2).lineTo(PAGE_W - MARGIN, bodyY - 2)
        .lineWidth(0.5).strokeColor(DIVIDER).stroke();
      bodyY += 6;
    }

    function sectionBody(text: string): void {
      setFont().fontSize(10).fillColor(MID);
      doc.text(text, MARGIN, bodyY, { width: CONTENT_W, lineGap: 2 });
      bodyY = doc.y + 10;
    }

    function sectionGap(): void {
      doc.moveTo(MARGIN, bodyY).lineTo(PAGE_W - MARGIN, bodyY)
        .lineWidth(0.5).strokeColor(DIVIDER).stroke();
      bodyY += 13;
    }

    const summary    = (content['summary']    as string | undefined) ?? '';
    const experience = (content['experience'] as string | undefined) || resume.experience || '';
    const education  = (content['education']  as string | undefined) ?? '';
    const languages  = (content['languages']  as string | undefined) ?? '';
    const aiScore        = content['aiScore']        as number | undefined;
    const aiScoreSummary = (content['aiScoreSummary'] as string | undefined) ?? '';

    if (summary) {
      sectionTitle('О себе');
      sectionBody(summary);
      sectionGap();
    }

    if (experience) {
      sectionTitle('Опыт работы');
      sectionBody(experience);
      sectionGap();
    }

    if (education) {
      sectionTitle('Образование');
      sectionBody(education);
      sectionGap();
    }

    if (resume.skills.length > 0) {
      sectionTitle('Навыки');

      const TAG_H = 20;
      const PAD_H = 10;
      const PAD_V = 4;
      let tagX = MARGIN;
      let tagY = bodyY;

      setFont().fontSize(9);
      for (const skill of resume.skills) {
        const tw = doc.widthOfString(skill) + PAD_H * 2;
        if (tagX + tw > PAGE_W - MARGIN) {
          tagX = MARGIN;
          tagY += TAG_H + 6;
        }
        doc.roundedRect(tagX, tagY, tw, TAG_H, 10).fill('#DBEAFE');
        setFont().fontSize(9).fillColor('#1E40AF')
          .text(skill, tagX + PAD_H, tagY + PAD_V, { width: tw - PAD_H * 2, lineBreak: false });
        tagX += tw + 8;
      }
      bodyY = tagY + TAG_H + 13;
      sectionGap();
    }

    if (languages) {
      sectionTitle('Языки');
      sectionBody(languages);
      if (aiScore != null) sectionGap();
    }

    if (aiScore != null) {
      sectionTitle(`Оценка Ассистента: ${aiScore}/100`);
      if (aiScoreSummary) sectionBody(aiScoreSummary);
    }

    doc.end();
  } catch (e) {
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

// POST /api/resume/:id/photo
export async function uploadResumePhoto(req: AuthRequest, res: Response): Promise<void> {
  if (!req.file) { fail(res, 'No photo provided'); return; }

  const { id } = req.params;
  const profile = await prisma.seekerProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) { fail(res, 'Profile not found', 404); return; }

  const existing = await prisma.resume.findFirst({
    where: { id, seekerId: profile.id },
  });
  if (!existing) { fail(res, 'Resume not found', 404); return; }

  const photoUrl = await uploadBuffer(
    req.file.buffer,
    req.file.mimetype,
    'ai-job-search/resume-photos',
    `photo-${id}-${Date.now()}`
  );

  const resume = await prisma.resume.update({
    where: { id },
    data: { photoUrl },
  });

  ok(res, { photoUrl: resume.photoUrl });
}