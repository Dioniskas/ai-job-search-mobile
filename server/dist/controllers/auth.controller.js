"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
exports.refresh = refresh;
exports.logout = logout;
exports.me = me;
exports.forgotPassword = forgotPassword;
exports.resetPassword = resetPassword;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = __importDefault(require("crypto"));
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
const email_service_1 = require("../services/email.service");
const email_notifications_controller_1 = require("../controllers/email-notifications.controller");
function signAccessToken(payload) {
    return jsonwebtoken_1.default.sign(payload, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
    });
}
function generateRefreshToken() {
    return crypto_1.default.randomBytes(64).toString('hex');
}
async function saveRefreshToken(userId, token) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await prisma_1.default.refreshToken.create({ data: { userId, token, expiresAt } });
}
function buildAuthResponse(userId, email, role) {
    const accessToken = signAccessToken({ userId, email, role });
    const refreshToken = generateRefreshToken();
    return { accessToken, refreshToken };
}
async function register(req, res) {
    const { email, password, role, firstName } = req.body;
    const exists = await prisma_1.default.user.findUnique({ where: { email } });
    if (exists) {
        (0, response_1.fail)(res, 'Email уже используется', 409);
        return;
    }
    const hashed = await bcryptjs_1.default.hash(password, 10);
    const user = await prisma_1.default.user.create({ data: { email, password: hashed, role } });
    const { accessToken, refreshToken } = buildAuthResponse(user.id, user.email, user.role);
    await saveRefreshToken(user.id, refreshToken);
    // Welcome email (fire-and-forget, non-blocking)
    const name = firstName?.trim() || email.split('@')[0];
    (0, email_service_1.sendWelcomeEmail)(email, name).catch(() => { });
    (0, response_1.ok)(res, {
        accessToken,
        refreshToken,
        user: { id: user.id, email: user.email, role: user.role },
    }, 201);
}
async function login(req, res) {
    const { email, password } = req.body;
    const user = await prisma_1.default.user.findUnique({ where: { email } });
    if (!user || !(await bcryptjs_1.default.compare(password, user.password))) {
        (0, response_1.fail)(res, 'Неверный email или пароль', 401);
        return;
    }
    if (user.isBlocked) {
        (0, response_1.fail)(res, 'Аккаунт заблокирован. Обратитесь в поддержку.', 401);
        return;
    }
    const { accessToken, refreshToken } = buildAuthResponse(user.id, user.email, user.role);
    await saveRefreshToken(user.id, refreshToken);
    (0, response_1.ok)(res, {
        accessToken,
        refreshToken,
        user: { id: user.id, email: user.email, role: user.role },
    });
}
async function refresh(req, res) {
    const { refreshToken } = req.body;
    try {
        const stored = await prisma_1.default.refreshToken.findUnique({ where: { token: refreshToken } });
        if (!stored || stored.expiresAt < new Date()) {
            if (stored)
                await prisma_1.default.refreshToken.delete({ where: { token: refreshToken } });
            (0, response_1.fail)(res, 'Refresh token недействителен или истёк', 401);
            return;
        }
        const user = await prisma_1.default.user.findUnique({ where: { id: stored.userId } });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        await prisma_1.default.refreshToken.delete({ where: { token: refreshToken } });
        const { accessToken, refreshToken: newRefreshToken } = buildAuthResponse(user.id, user.email, user.role);
        await saveRefreshToken(user.id, newRefreshToken);
        (0, response_1.ok)(res, { accessToken, refreshToken: newRefreshToken });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function logout(req, res) {
    const { refreshToken } = req.body;
    if (refreshToken) {
        await prisma_1.default.refreshToken.deleteMany({ where: { token: refreshToken } }).catch(() => { });
    }
    (0, response_1.ok)(res, { loggedOut: true });
}
async function me(req, res) {
    try {
        const user = await prisma_1.default.user.findUnique({
            where: { id: req.user.userId },
            select: {
                id: true,
                email: true,
                role: true,
                createdAt: true,
                seekerProfile: {
                    select: { firstName: true, lastName: true, photoUrl: true, city: true },
                },
                employerProfile: {
                    select: { companyName: true, logoUrl: true, city: true },
                },
            },
        });
        if (!user) {
            (0, response_1.fail)(res, 'Пользователь не найден', 404);
            return;
        }
        (0, response_1.ok)(res, { user });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/auth/forgot-password
async function forgotPassword(req, res) {
    const { email } = req.body;
    if (!email) {
        (0, response_1.fail)(res, 'Email обязателен');
        return;
    }
    try {
        const user = await prisma_1.default.user.findUnique({ where: { email } });
        // Always return success to avoid user enumeration
        if (!user) {
            (0, response_1.ok)(res, { message: 'Если email существует, письмо отправлено' });
            return;
        }
        const prefs = (0, email_notifications_controller_1.getEmailPrefs)(user.emailNotifications);
        if (!prefs.passwordReset) {
            (0, response_1.ok)(res, { message: 'Если email существует, письмо отправлено' });
            return;
        }
        const token = crypto_1.default.randomBytes(32).toString('hex');
        const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
        await prisma_1.default.user.update({
            where: { id: user.id },
            data: { passwordResetToken: token, passwordResetExpires: expires },
        });
        (0, email_service_1.sendPasswordResetEmail)(email, token).catch(() => { });
        (0, response_1.ok)(res, { message: 'Если email существует, письмо отправлено' });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
// POST /api/auth/reset-password
async function resetPassword(req, res) {
    const { token, password } = req.body;
    if (!token || !password) {
        (0, response_1.fail)(res, 'token и password обязательны');
        return;
    }
    if (password.length < 6) {
        (0, response_1.fail)(res, 'Пароль минимум 6 символов');
        return;
    }
    try {
        const user = await prisma_1.default.user.findFirst({
            where: {
                passwordResetToken: token,
                passwordResetExpires: { gt: new Date() },
            },
        });
        if (!user) {
            (0, response_1.fail)(res, 'Токен недействителен или истёк', 400);
            return;
        }
        const hashed = await bcryptjs_1.default.hash(password, 10);
        await prisma_1.default.user.update({
            where: { id: user.id },
            data: {
                password: hashed,
                passwordResetToken: null,
                passwordResetExpires: null,
            },
        });
        // Invalidate all refresh tokens for security
        await prisma_1.default.refreshToken.deleteMany({ where: { userId: user.id } });
        (0, response_1.ok)(res, { message: 'Пароль успешно изменён' });
    }
    catch (e) {
        (0, response_1.fail)(res, `Ошибка сервера: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
