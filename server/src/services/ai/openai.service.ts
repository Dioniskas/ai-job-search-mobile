import OpenAI, { toFile } from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export interface ResumeContent {
  title: string;
  summary: string;
  experience: string;
  education: string;
  skills: string[];
  rawText?: string;
}

const SYSTEM_RESUME = `You are a professional resume writer. Always respond with valid JSON only — no markdown, no extra text.
Return an object with these fields:
  title (string): concise professional job title
  summary (string): 2-3 sentence professional summary
  experience (string): work experience, formatted clearly
  education (string): education background
  skills (array of strings): list of professional skills`;

function parseResumeJson(raw: string): ResumeContent {
  try {
    const parsed = JSON.parse(raw) as Partial<ResumeContent>;
    return {
      title:      parsed.title      ?? 'Специалист',
      summary:    parsed.summary    ?? '',
      experience: parsed.experience ?? '',
      education:  parsed.education  ?? '',
      skills:     Array.isArray(parsed.skills) ? parsed.skills : [],
    };
  } catch {
    return { title: 'Специалист', summary: raw.slice(0, 500), experience: '', education: '', skills: [] };
  }
}

async function chatJson(userPrompt: string): Promise<ResumeContent> {
  const resp = await openai.chat.completions.create({
    model: 'gpt-4o',
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: SYSTEM_RESUME },
      { role: 'user',   content: userPrompt },
    ],
    max_tokens: 1500,
  });
  return parseResumeJson(resp.choices[0].message.content ?? '{}');
}

export async function improveResume(rawText: string): Promise<ResumeContent> {
  return chatJson(
    `Improve and structure the following resume text into a professional resume:\n\n${rawText.slice(0, 6000)}`
  );
}

export async function generateResumeFromForm(data: {
  name: string;
  age?: string;
  experience: string;
  skills: string;
  about?: string;
}): Promise<ResumeContent> {
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

export async function generateResumeFromTranscript(transcript: string): Promise<ResumeContent> {
  return chatJson(
    `The following is a spoken description of a person's work background. Create a professional resume from it:\n\n${transcript.slice(0, 4000)}`
  );
}

export async function transcribeAudio(buffer: Buffer, mimetype: string): Promise<string> {
  const ext = mimetype.includes('webm') ? 'webm'
    : mimetype.includes('ogg')  ? 'ogg'
    : mimetype.includes('mp4')  ? 'mp4'
    : mimetype.includes('wav')  ? 'wav'
    : 'webm';

  const audioFile = await toFile(buffer, `recording.${ext}`, { type: mimetype });

  const transcription = await openai.audio.transcriptions.create({
    file:  audioFile,
    model: 'whisper-1',
    language: 'ru',
  });
  return transcription.text;
}
