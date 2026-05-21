"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createReport = createReport;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const SPAM_THRESHOLD = 3;
async function createReport(req, res) {
    const { targetId, targetType, reason } = req.body;
    if (!targetId || !targetType || !reason) {
        (0, response_1.fail)(res, 'targetId, targetType и reason обязательны');
        return;
    }
    if (targetType !== 'vacancy' && targetType !== 'user') {
        (0, response_1.fail)(res, 'targetType должен быть "vacancy" или "user"');
        return;
    }
    try {
        const report = await prisma_1.default.report.create({
            data: {
                reporterId: req.user.userId,
                targetId,
                targetType,
                reason,
            },
        });
        // Auto-block spam: if 3+ reports on a user → hide their vacancies
        if (targetType === 'user') {
            const count = await prisma_1.default.report.count({
                where: { targetId, targetType: 'user' },
            });
            if (count >= SPAM_THRESHOLD) {
                const user = await prisma_1.default.user.findUnique({ where: { id: targetId } });
                if (user && user.role === 'EMPLOYER') {
                    const employer = await prisma_1.default.employer.findUnique({ where: { userId: targetId } });
                    if (employer) {
                        await prisma_1.default.vacancy.updateMany({
                            where: { employerId: employer.id, isActive: true },
                            data: { isActive: false },
                        });
                    }
                }
            }
        }
        (0, response_1.ok)(res, { report }, 201);
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
