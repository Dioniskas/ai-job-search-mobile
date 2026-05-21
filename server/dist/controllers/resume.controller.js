"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initFonts = initFonts;
exports.getResumes = getResumes;
exports.uploadPdf = uploadPdf;
exports.improvePdf = improvePdf;
exports.generateFromText = generateFromText;
exports.generateFromVoice = generateFromVoice;
exports.updateResume = updateResume;
exports.scoreResumeCtrl = scoreResumeCtrl;
exports.generateResumePdf = generateResumePdf;
exports.deleteResume = deleteResume;
const pdf_parse_1 = __importDefault(require("pdf-parse"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const response_1 = require("../utils/response");
const imagekit_service_1 = require("../services/imagekit.service");
const prisma_1 = __importDefault(require("../lib/prisma"));
const groq_service_1 = require("../services/ai/groq.service");
function initFonts() {
    const fontPath = path_1.default.join(process.cwd(), 'fonts', 'DejaVuSans.ttf');
    if (fs_1.default.existsSync(fontPath)) {
        return fontPath;
    }
    console.error('[resume] DejaVuSans.ttf not found at', fontPath, '— PDF output will use default font');
    return null;
}
async function getOrCreateProfile(userId) {
    const existing = await prisma_1.default.seekerProfile.findUnique({ where: { userId } });
    if (existing)
        return existing;
    return prisma_1.default.seekerProfile.create({
        data: { userId, firstName: '', lastName: '' },
    });
}
function resumeTitle(content, fallback = 'Моё резюме') {
    return content.title || fallback;
}
// GET /api/resume
async function getResumes(req, res) {
    const profile = await prisma_1.default.seekerProfile.findUnique({
        where: { userId: req.user.userId },
    });
    if (!profile) {
        (0, response_1.ok)(res, { resumes: [] });
        return;
    }
    const resumes = await prisma_1.default.resume.findMany({
        where: { seekerId: profile.id },
        orderBy: { updatedAt: 'desc' },
    });
    (0, response_1.ok)(res, { resumes });
}
// POST /api/resume/upload — Way 1: PDF → extract text → save as-is
async function uploadPdf(req, res) {
    if (!req.file) {
        (0, response_1.fail)(res, 'No PDF file provided');
        return;
    }
    const profile = await getOrCreateProfile(req.user.userId);
    const [pdfUrl, parsed] = await Promise.all([
        (0, imagekit_service_1.uploadBuffer)(req.file.buffer, req.file.mimetype, 'ai-job-search/resumes', `resume-${profile.id}-${Date.now()}`),
        (0, pdf_parse_1.default)(req.file.buffer),
    ]);
    const rawText = parsed.text.trim();
    const content = {
        title: 'Резюме из PDF',
        summary: '',
        experience: rawText,
        education: '',
        skills: [],
        rawText,
    };
    const resume = await prisma_1.default.resume.create({
        data: {
            seekerId: profile.id,
            title: content.title,
            content: content,
            pdfUrl,
            isAiGenerated: false,
            skills: [],
            experience: rawText.slice(0, 500),
        },
    });
    (0, response_1.ok)(res, { resume }, 201);
}
// POST /api/resume/improve — Way 2: PDF → AI improve → save
async function improvePdf(req, res) {
    if (!req.file) {
        (0, response_1.fail)(res, 'No PDF file provided');
        return;
    }
    const profile = await getOrCreateProfile(req.user.userId);
    const [pdfUrl, parsed] = await Promise.all([
        (0, imagekit_service_1.uploadBuffer)(req.file.buffer, req.file.mimetype, 'ai-job-search/resumes', `resume-${profile.id}-${Date.now()}`),
        (0, pdf_parse_1.default)(req.file.buffer),
    ]);
    const rawText = parsed.text.trim();
    if (!rawText) {
        (0, response_1.fail)(res, 'Could not extract text from PDF');
        return;
    }
    let content;
    try {
        content = await (0, groq_service_1.improveResume)(rawText);
    }
    catch (e) {
        (0, response_1.fail)(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
        return;
    }
    const resume = await prisma_1.default.resume.create({
        data: {
            seekerId: profile.id,
            title: resumeTitle(content, 'Улучшенное резюме'),
            content: content,
            pdfUrl,
            isAiGenerated: true,
            skills: content.skills,
            experience: content.experience.slice(0, 500),
        },
    });
    (0, response_1.ok)(res, { resume }, 201);
}
// POST /api/resume/generate/text — Way 3: form → GPT-4o → save
async function generateFromText(req, res) {
    const { name, age, experience, skills, about } = req.body;
    if (!name || !experience || !skills) {
        (0, response_1.fail)(res, 'name, experience and skills are required');
        return;
    }
    const profile = await getOrCreateProfile(req.user.userId);
    let content;
    try {
        content = await (0, groq_service_1.generateResumeFromForm)({ name, age, experience, skills, about });
    }
    catch (e) {
        (0, response_1.fail)(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
        return;
    }
    const resume = await prisma_1.default.resume.create({
        data: {
            seekerId: profile.id,
            title: resumeTitle(content, 'Резюме из формы'),
            content: content,
            isAiGenerated: true,
            skills: content.skills,
            experience: content.experience.slice(0, 500),
        },
    });
    (0, response_1.ok)(res, { resume }, 201);
}
// POST /api/resume/generate/voice — Way 4: audio → Whisper → GPT-4o → save
async function generateFromVoice(req, res) {
    if (!req.file) {
        (0, response_1.fail)(res, 'No audio file provided');
        return;
    }
    const profile = await getOrCreateProfile(req.user.userId);
    let transcript;
    try {
        transcript = await (0, groq_service_1.transcribeAudio)(req.file.buffer, req.file.mimetype);
    }
    catch (e) {
        (0, response_1.fail)(res, `Transcription error: ${e instanceof Error ? e.message : 'unknown'}`);
        return;
    }
    if (!transcript.trim()) {
        (0, response_1.fail)(res, 'Could not transcribe audio');
        return;
    }
    let content;
    try {
        content = await (0, groq_service_1.generateResumeFromTranscript)(transcript);
    }
    catch (e) {
        (0, response_1.fail)(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
        return;
    }
    const resume = await prisma_1.default.resume.create({
        data: {
            seekerId: profile.id,
            title: resumeTitle(content, 'Резюме из голоса'),
            content: { ...content, transcript },
            isAiGenerated: true,
            skills: content.skills,
            experience: content.experience.slice(0, 500),
        },
    });
    (0, response_1.ok)(res, { resume }, 201);
}
// PUT /api/resume/:id
async function updateResume(req, res) {
    const { id } = req.params;
    const { title, content, skills, experience } = req.body;
    const profile = await prisma_1.default.seekerProfile.findUnique({
        where: { userId: req.user.userId },
    });
    if (!profile) {
        (0, response_1.fail)(res, 'Profile not found', 404);
        return;
    }
    const existing = await prisma_1.default.resume.findFirst({
        where: { id, seekerId: profile.id },
    });
    if (!existing) {
        (0, response_1.fail)(res, 'Resume not found', 404);
        return;
    }
    const updated = await prisma_1.default.resume.update({
        where: { id },
        data: {
            ...(title && { title }),
            ...(content && { content: content }),
            ...(skills && { skills }),
            ...(experience !== undefined && { experience }),
        },
    });
    (0, response_1.ok)(res, { resume: updated });
}
// POST /api/resume/:id/score
async function scoreResumeCtrl(req, res) {
    const { id } = req.params;
    const profile = await prisma_1.default.seekerProfile.findUnique({
        where: { userId: req.user.userId },
    });
    if (!profile) {
        (0, response_1.fail)(res, 'Profile not found', 404);
        return;
    }
    const existing = await prisma_1.default.resume.findFirst({
        where: { id, seekerId: profile.id },
    });
    if (!existing) {
        (0, response_1.fail)(res, 'Resume not found', 404);
        return;
    }
    let scoreResult;
    try {
        const content = existing.content;
        scoreResult = await (0, groq_service_1.scoreResume)(content);
    }
    catch (e) {
        (0, response_1.fail)(res, `AI error: ${e instanceof Error ? e.message : 'unknown'}`);
        return;
    }
    // Persist score in content JSON
    const existingContent = existing.content ?? {};
    const updatedContent = {
        ...existingContent,
        aiScore: scoreResult.score,
        aiScoreStrengths: scoreResult.strengths,
        aiScoreImprovements: scoreResult.improvements,
        aiScoreSummary: scoreResult.summary,
    };
    const resume = await prisma_1.default.resume.update({
        where: { id },
        data: { content: updatedContent },
    });
    (0, response_1.ok)(res, {
        resume: {
            ...resume,
            aiScore: scoreResult.score,
            aiScoreDetails: scoreResult,
        },
    });
}
// GET /api/resume/:id/pdf
async function generateResumePdf(req, res) {
    const { id } = req.params;
    const profile = await prisma_1.default.seekerProfile.findUnique({
        where: { userId: req.user.userId },
    });
    if (!profile) {
        console.error('[pdf] error:', 'Profile not found');
        (0, response_1.fail)(res, 'Profile not found', 404);
        return;
    }
    const existing = await prisma_1.default.resume.findFirst({
        where: { id, seekerId: profile.id },
    });
    if (!existing) {
        console.error('[pdf] error:', 'Resume not found');
        (0, response_1.fail)(res, 'Resume not found', 404);
        return;
    }
    console.log('[pdf] generating for resume:', id, 'user:', req.user?.userId);
    const content = existing.content;
    const fontPath = initFonts();
    const doc = new pdfkit_1.default({ margin: 50 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    const pdfDone = new Promise((resolve, reject) => {
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);
    });
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
        doc.fontSize(11).text(content.skills.join(', '));
        doc.moveDown();
    }
    doc.end();
    const pdfBuffer = await pdfDone;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="resume-${id}.pdf"`);
    res.send(pdfBuffer);
}
// DELETE /api/resume/:id
async function deleteResume(req, res) {
    const { id } = req.params;
    const profile = await prisma_1.default.seekerProfile.findUnique({
        where: { userId: req.user.userId },
    });
    if (!profile) {
        (0, response_1.fail)(res, 'Profile not found', 404);
        return;
    }
    const existing = await prisma_1.default.resume.findFirst({
        where: { id, seekerId: profile.id },
    });
    if (!existing) {
        (0, response_1.fail)(res, 'Resume not found', 404);
        return;
    }
    await prisma_1.default.resume.delete({ where: { id } });
    (0, response_1.ok)(res, { deleted: true });
}
