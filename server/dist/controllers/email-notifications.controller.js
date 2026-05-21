"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getEmailPrefs = getEmailPrefs;
exports.getEmailNotifications = getEmailNotifications;
exports.updateEmailNotifications = updateEmailNotifications;
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const DEFAULT_SETTINGS = {
    welcome: true,
    newApplication: true,
    applicationStatus: true,
    interview: true,
    passwordReset: true,
};
function getEmailPrefs(raw) {
    if (!raw || typeof raw !== 'object')
        return { ...DEFAULT_SETTINGS };
    const s = raw;
    return {
        welcome: s.welcome ?? true,
        newApplication: s.newApplication ?? true,
        applicationStatus: s.applicationStatus ?? true,
        interview: s.interview ?? true,
        passwordReset: s.passwordReset ?? true,
    };
}
// GET /api/users/email-notifications
async function getEmailNotifications(req, res) {
    try {
        const user = await prisma_1.default.user.findUnique({
            where: { id: req.user.userId },
            select: { emailNotifications: true },
        });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        (0, response_1.ok)(res, { settings: getEmailPrefs(user.emailNotifications) });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// PUT /api/users/email-notifications
async function updateEmailNotifications(req, res) {
    const body = req.body;
    const allowed = ['welcome', 'newApplication', 'applicationStatus', 'interview', 'passwordReset'];
    try {
        const user = await prisma_1.default.user.findUnique({
            where: { id: req.user.userId },
            select: { emailNotifications: true },
        });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        const current = getEmailPrefs(user.emailNotifications);
        const updated = { ...current };
        for (const key of allowed) {
            const val = body[key];
            if (typeof val === 'boolean')
                updated[key] = val;
        }
        await prisma_1.default.user.update({
            where: { id: req.user.userId },
            data: { emailNotifications: updated },
        });
        (0, response_1.ok)(res, { settings: updated });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
