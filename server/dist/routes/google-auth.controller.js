"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.googleMobileAuth = googleMobileAuth;
const google_auth_library_1 = require("google-auth-library");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const prisma_1 = __importDefault(require("../lib/prisma"));
const response_1 = require("../utils/response");
const client = new google_auth_library_1.OAuth2Client(process.env.GOOGLE_CLIENT_ID);
// POST /api/auth/google/mobile
// Flutter отправляет idToken полученный от google_sign_in
async function googleMobileAuth(req, res) {
    const { idToken } = req.body;
    if (!idToken) {
        (0, response_1.fail)(res, 'idToken is required');
        return;
    }
    let payload;
    try {
        const ticket = await client.verifyIdToken({
            idToken,
            audience: [
                process.env.GOOGLE_CLIENT_ID,
                // Android client id
                '310538934424-ob4g36nbd2p1fl7gqdkumm45j1kbhuh9.apps.googleusercontent.com',
            ],
        });
        payload = ticket.getPayload();
    }
    catch (e) {
        (0, response_1.fail)(res, 'Invalid Google token', 401);
        return;
    }
    if (!payload?.email) {
        (0, response_1.fail)(res, 'No email in Google token', 401);
        return;
    }
    const { email, name, picture, sub: googleId } = payload;
    // Find or create user
    let user = await prisma_1.default.user.findUnique({ where: { email } });
    if (!user) {
        // New user — create with SEEKER role by default
        user = await prisma_1.default.user.create({
            data: {
                email,
                password: `google_${googleId}`, // not used for login
                role: 'SEEKER',
            },
        });
        // Create seeker profile with Google data
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
    if (user.isBlocked) {
        (0, response_1.fail)(res, 'Аккаунт заблокирован', 403);
        return;
    }
    // Issue JWT tokens
    const accessToken = jsonwebtoken_1.default.sign({ userId: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN ?? '15m' });
    const refreshToken = jsonwebtoken_1.default.sign({ userId: user.id }, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d' });
    // Save refresh token
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await prisma_1.default.refreshToken.create({
        data: { userId: user.id, token: refreshToken, expiresAt },
    });
    (0, response_1.ok)(res, {
        accessToken,
        refreshToken,
        user: {
            id: user.id,
            email: user.email,
            role: user.role,
        },
    });
}
