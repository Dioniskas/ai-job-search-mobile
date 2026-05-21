import { Response } from 'express';
import { AuthRequest } from '../types';
import { ok, fail } from '../utils/response';
import prisma from '../lib/prisma';
import { getTestMeta, getTestBySkill } from '../data/skills-data';

export async function listSkillTests(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;

    const seeker = await prisma.seekerProfile.findUnique({ where: { userId } });
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const existingTests = await prisma.skillTest.findMany({
      where: { seekerId: seeker.id },
      orderBy: { passedAt: 'desc' },
    });

    const bestScores: Record<string, { score: number; passedAt: Date }> = {};
    for (const t of existingTests) {
      if (!bestScores[t.skill] || t.score > bestScores[t.skill].score) {
        bestScores[t.skill] = { score: t.score, passedAt: t.passedAt };
      }
    }

    const tests = getTestMeta().map((meta) => ({
      ...meta,
      questionsCount: 10,
      userBest: bestScores[meta.skill] ?? null,
      hasBadge: (bestScores[meta.skill]?.score ?? 0) >= 70,
    }));

    ok(res, { tests });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function getSkillTestQuestions(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { skill } = req.params as { skill: string };
    const testData = getTestBySkill(skill);
    if (!testData) { fail(res, 'Тест не найден', 404); return; }

    // Return questions without correctIndex (security)
    const questions = testData.questions.map(({ text, options }) => ({ text, options }));

    ok(res, {
      skill: testData.skill,
      title: testData.title,
      description: testData.description,
      questions,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}

export async function submitSkillTest(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { userId } = req.user!;
    const { skill } = req.params as { skill: string };
    const { answers } = req.body as { answers: number[] };

    if (!Array.isArray(answers)) { fail(res, 'answers должен быть массивом'); return; }

    const testData = getTestBySkill(skill);
    if (!testData) { fail(res, 'Тест не найден', 404); return; }

    if (answers.length !== testData.questions.length) {
      fail(res, `Ожидается ${testData.questions.length} ответов`); return;
    }

    let correct = 0;
    const results = testData.questions.map((q, i) => {
      const isCorrect = answers[i] === q.correctIndex;
      if (isCorrect) correct++;
      return { isCorrect, correctIndex: q.correctIndex };
    });

    const score = Math.round((correct / testData.questions.length) * 100);
    const passed = score >= 70;

    const seeker = await prisma.seekerProfile.findUnique({ where: { userId } });
    if (!seeker) { fail(res, 'Профиль не найден', 404); return; }

    const skillTest = await prisma.skillTest.create({
      data: { seekerId: seeker.id, skill, score },
    });

    ok(res, {
      score,
      passed,
      correct,
      total: testData.questions.length,
      badge: passed ? { skill, title: testData.title, score } : null,
      results,
      testId: skillTest.id,
    });
  } catch (e) {
    fail(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
  }
}
