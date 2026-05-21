"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSkillTests = listSkillTests;
exports.getSkillTestQuestions = getSkillTestQuestions;
exports.submitSkillTest = submitSkillTest;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const skills_data_1 = require("../data/skills-data");
async function listSkillTests(req, res) {
    try {
        const { userId } = req.user;
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const existingTests = await prisma_1.default.skillTest.findMany({
            where: { seekerId: seeker.id },
            orderBy: { passedAt: 'desc' },
        });
        const bestScores = {};
        for (const t of existingTests) {
            if (!bestScores[t.skill] || t.score > bestScores[t.skill].score) {
                bestScores[t.skill] = { score: t.score, passedAt: t.passedAt };
            }
        }
        const tests = (0, skills_data_1.getTestMeta)().map((meta) => ({
            ...meta,
            questionsCount: 10,
            userBest: bestScores[meta.skill] ?? null,
            hasBadge: (bestScores[meta.skill]?.score ?? 0) >= 70,
        }));
        (0, response_1.ok)(res, { tests });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function getSkillTestQuestions(req, res) {
    try {
        const { skill } = req.params;
        const testData = (0, skills_data_1.getTestBySkill)(skill);
        if (!testData) {
            (0, response_1.fail)(res, 'Тест не найден', 404);
            return;
        }
        // Return questions without correctIndex (security)
        const questions = testData.questions.map(({ text, options }) => ({ text, options }));
        (0, response_1.ok)(res, {
            skill: testData.skill,
            title: testData.title,
            description: testData.description,
            questions,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function submitSkillTest(req, res) {
    try {
        const { userId } = req.user;
        const { skill } = req.params;
        const { answers } = req.body;
        if (!Array.isArray(answers)) {
            (0, response_1.fail)(res, 'answers должен быть массивом');
            return;
        }
        const testData = (0, skills_data_1.getTestBySkill)(skill);
        if (!testData) {
            (0, response_1.fail)(res, 'Тест не найден', 404);
            return;
        }
        if (answers.length !== testData.questions.length) {
            (0, response_1.fail)(res, `Ожидается ${testData.questions.length} ответов`);
            return;
        }
        let correct = 0;
        const results = testData.questions.map((q, i) => {
            const isCorrect = answers[i] === q.correctIndex;
            if (isCorrect)
                correct++;
            return { isCorrect, correctIndex: q.correctIndex };
        });
        const score = Math.round((correct / testData.questions.length) * 100);
        const passed = score >= 70;
        const seeker = await prisma_1.default.seekerProfile.findUnique({ where: { userId } });
        if (!seeker) {
            (0, response_1.fail)(res, 'Профиль не найден', 404);
            return;
        }
        const skillTest = await prisma_1.default.skillTest.create({
            data: { seekerId: seeker.id, skill, score },
        });
        (0, response_1.ok)(res, {
            score,
            passed,
            correct,
            total: testData.questions.length,
            badge: passed ? { skill, title: testData.title, score } : null,
            results,
            testId: skillTest.id,
        });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
