"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.googleMobileAuth = googleMobileAuth;
exports.googleCompleteAuth = googleCompleteAuth;
const google_auth_library_1 = require("google-auth-library");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const prisma_1 = __importDefault(require("../lib/prisma"));
const response_1 = require("../utils/response");
const client = new google_auth_library_1.OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const AUDIENCE = [
    '543184751033-9c7squ54rcf57b1spqalkhohrqug5vvp.apps.googleusercontent.com',
    '543184751033-u2b74vsdbdhobs69gp8t337lavm0k4ve.apps.googleusercontent.com',
];
function issueTokens(userId, role) {
    const accessToken = jsonwebtoken_1.default.sign({ userId, role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN ?? '15m' });
    const refreshToken = jsonwebtoken_1.default.sign({ userId }, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d' });
    return { accessToken, refreshToken };
}
async function saveRefreshToken(userId, token) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await prisma_1.default.refreshToken.create({ data: { userId, token, expiresAt } });
}
// POST /api/auth/google/mobile
async function googleMobileAuth(req, res) {
    const { idToken } = req.body;
    if (!idToken) {
        (0, response_1.fail)(res, 'idToken is required');
        return;
    }
    let payload;
    try {
        const ticket = await client.verifyIdToken({ idToken, audience: AUDIENCE });
        payload = ticket.getPayload();
    }
    catch {
        (0, response_1.fail)(res, 'Invalid Google token', 401);
        return;
    }
    if (!payload?.email) {
        (0, response_1.fail)(res, 'No email in Google token', 401);
        return;
    }
    const { email, name, picture } = payload;
    const user = await prisma_1.default.user.findUnique({ where: { email } });
    if (!user) {
        (0, response_1.ok)(res, { isNewUser: true, googleData: { email, name, picture } });
        return;
    }
    if (user.isBlocked) {
        (0, response_1.fail)(res, 'Аккаунт заблокирован', 403);
        return;
    }
    const { accessToken, refreshToken } = issueTokens(user.id, user.role);
    await saveRefreshToken(user.id, refreshToken);
    (0, response_1.ok)(res, {
        isNewUser: false,
        accessToken,
        refreshToken,
        user: { id: user.id, email: user.email, role: user.role },
    });
}
// POST /api/auth/google/complete
async function googleCompleteAuth(req, res) {
    const { email, name, picture, role } = req.body;
    if (!email || !role || !['SEEKER', 'EMPLOYER'].includes(role)) {
        (0, response_1.fail)(res, 'email and role (SEEKER|EMPLOYER) are required');
        return;
    }
    const existing = await prisma_1.default.user.findUnique({ where: { email } });
    if (existing) {
        (0, response_1.fail)(res, 'Пользователь уже существует', 409);
        return;
    }
    const user = await prisma_1.default.user.create({
        data: { email, password: `google_${Date.now()}`, role: role },
    });
    if (role === 'SEEKER') {
        const nameParts = (name ?? '').split(' ');
        await prisma_1.default.seekerProfile.create({
            data: {
                userId: user.id,
                firstName: nameParts[0] ?? '',
                lastName: nameParts.slice(1).join(' ') ?? '',
                photoUrl: picture,
            },
        });
    }
    else {
        await prisma_1.default.employer.create({
            data: { userId: user.id, companyName: name ?? '' },
        });
    }
    const { accessToken, refreshToken } = issueTokens(user.id, user.role);
    await saveRefreshToken(user.id, refreshToken);
    (0, response_1.ok)(res, {
        accessToken,
        refreshToken,
        user: { id: user.id, email: user.email, role: user.role },
    });
}
