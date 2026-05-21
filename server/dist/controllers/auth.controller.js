"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
exports.me = me;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const client_1 = require("@prisma/client");
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
function signToken(payload) {
    return jsonwebtoken_1.default.sign(payload, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
    });
}
async function register(req, res) {
    const { email, password, role } = req.body;
    if (!email || !password || !role) {
        (0, response_1.fail)(res, 'email, password and role are required');
        return;
    }
    if (!Object.values(client_1.Role).includes(role)) {
        (0, response_1.fail)(res, 'role must be SEEKER or EMPLOYER');
        return;
    }
    if (password.length < 6) {
        (0, response_1.fail)(res, 'password must be at least 6 characters');
        return;
    }
    const exists = await prisma_1.default.user.findUnique({ where: { email } });
    if (exists) {
        (0, response_1.fail)(res, 'Email already in use', 409);
        return;
    }
    const hashed = await bcryptjs_1.default.hash(password, 10);
    const user = await prisma_1.default.user.create({
        data: { email, password: hashed, role },
    });
    const token = signToken({ userId: user.id, email: user.email, role: user.role });
    (0, response_1.ok)(res, { token, user: { id: user.id, email: user.email, role: user.role } }, 201);
}
async function login(req, res) {
    const { email, password } = req.body;
    if (!email || !password) {
        (0, response_1.fail)(res, 'email and password are required');
        return;
    }
    const user = await prisma_1.default.user.findUnique({ where: { email } });
    if (!user || !(await bcryptjs_1.default.compare(password, user.password))) {
        (0, response_1.fail)(res, 'Invalid credentials', 401);
        return;
    }
    const token = signToken({ userId: user.id, email: user.email, role: user.role });
    (0, response_1.ok)(res, { token, user: { id: user.id, email: user.email, role: user.role } });
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
            (0, response_1.fail)(res, 'User not found', 404);
            return;
        }
        (0, response_1.ok)(res, { user });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
