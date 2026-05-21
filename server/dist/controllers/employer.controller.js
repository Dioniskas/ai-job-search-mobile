"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProfile = getProfile;
exports.upsertProfile = upsertProfile;
exports.uploadLogo = uploadLogo;
const response_1 = require("../utils/response");
const imagekit_service_1 = require("../services/imagekit.service");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function getProfile(req, res) {
    try {
        const profile = await prisma_1.default.employer.findUnique({
            where: { userId: req.user.userId },
        });
        (0, response_1.ok)(res, { profile: profile ?? null });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function upsertProfile(req, res) {
    const { companyName, description, website, city } = req.body;
    if (!companyName) {
        (0, response_1.fail)(res, 'companyName is required');
        return;
    }
    const data = {
        companyName,
        description: description ?? null,
        website: website ?? null,
        city: city ?? null,
    };
    try {
        const profile = await prisma_1.default.employer.upsert({
            where: { userId: req.user.userId },
            create: { userId: req.user.userId, ...data },
            update: data,
        });
        (0, response_1.ok)(res, { profile });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function uploadLogo(req, res) {
    if (!req.file) {
        (0, response_1.fail)(res, 'No file provided');
        return;
    }
    try {
        const logoUrl = await (0, imagekit_service_1.uploadBuffer)(req.file.buffer, req.file.mimetype, 'ai-job-search/logos', `employer-${req.user.userId}`);
        const profile = await prisma_1.default.employer.upsert({
            where: { userId: req.user.userId },
            create: { userId: req.user.userId, companyName: '', logoUrl },
            update: { logoUrl },
        });
        (0, response_1.ok)(res, { logoUrl: profile.logoUrl });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
