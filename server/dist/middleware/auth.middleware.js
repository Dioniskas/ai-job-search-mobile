"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticate = authenticate;
exports.requireRole = requireRole;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const response_1 = require("../utils/response");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function authenticate(req, res, next) {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
        (0, response_1.fail)(res, 'Unauthorized', 401);
        return;
    }
    try {
        const token = header.split(' ')[1];
        const payload = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
        const exists = await prisma_1.default.user.findUnique({
            where: { id: payload.userId },
            select: { id: true },
        });
        if (!exists) {
            (0, response_1.fail)(res, 'Пользователь не найден — войдите снова', 401);
            return;
        }
        req.user = payload;
        next();
    }
    catch {
        (0, response_1.fail)(res, 'Invalid or expired token', 401);
    }
}
function requireRole(...roles) {
    return (req, res, next) => {
        if (!req.user || !roles.includes(req.user.role)) {
            (0, response_1.fail)(res, 'Forbidden', 403);
            return;
        }
        next();
    };
}
