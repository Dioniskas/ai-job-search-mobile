"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.improveResume = improveResume;
exports.generateResumeFromForm = generateResumeFromForm;
exports.generateResumeFromTranscript = generateResumeFromTranscript;
exports.transcribeAudio = transcribeAudio;
const openai_1 = __importStar(require("openai"));
const openai = new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
const SYSTEM_RESUME = `You are a professional resume writer. Always respond with valid JSON only — no markdown, no extra text.
Return an object with these fields:
  title (string): concise professional job title
  summary (string): 2-3 sentence professional summary
  experience (string): work experience, formatted clearly
  education (string): education background
  skills (array of strings): list of professional skills`;
function parseResumeJson(raw) {
    try {
        const parsed = JSON.parse(raw);
        return {
            title: parsed.title ?? 'Специалист',
            summary: parsed.summary ?? '',
            experience: parsed.experience ?? '',
            education: parsed.education ?? '',
            skills: Array.isArray(parsed.skills) ? parsed.skills : [],
        };
    }
    catch {
        return { title: 'Специалист', summary: raw.slice(0, 500), experience: '', education: '', skills: [] };
    }
}
async function chatJson(userPrompt) {
    const resp = await openai.chat.completions.create({
        model: 'gpt-4o',
        response_format: { type: 'json_object' },
        messages: [
            { role: 'system', content: SYSTEM_RESUME },
            { role: 'user', content: userPrompt },
        ],
        max_tokens: 1500,
    });
    return parseResumeJson(resp.choices[0].message.content ?? '{}');
}
async function improveResume(rawText) {
    return chatJson(`Improve and structure the following resume text into a professional resume:\n\n${rawText.slice(0, 6000)}`);
}
async function generateResumeFromForm(data) {
    const prompt = [
        `Create a professional resume for:`,
        `Name: ${data.name}`,
        data.age ? `Age: ${data.age}` : '',
        `Experience: ${data.experience}`,
        `Skills: ${data.skills}`,
        data.about ? `About: ${data.about}` : '',
    ].filter(Boolean).join('\n');
    return chatJson(prompt);
}
async function generateResumeFromTranscript(transcript) {
    return chatJson(`The following is a spoken description of a person's work background. Create a professional resume from it:\n\n${transcript.slice(0, 4000)}`);
}
async function transcribeAudio(buffer, mimetype) {
    const ext = mimetype.includes('webm') ? 'webm'
        : mimetype.includes('ogg') ? 'ogg'
            : mimetype.includes('mp4') ? 'mp4'
                : mimetype.includes('wav') ? 'wav'
                    : 'webm';
    const audioFile = await (0, openai_1.toFile)(buffer, `recording.${ext}`, { type: mimetype });
    const transcription = await openai.audio.transcriptions.create({
        file: audioFile,
        model: 'whisper-1',
        language: 'ru',
    });
    return transcription.text;
}
