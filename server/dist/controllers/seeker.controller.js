"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProfile = getProfile;
exports.upsertProfile = upsertProfile;
exports.uploadPhoto = uploadPhoto;
exports.setVisibility = setVisibility;
const response_1 = require("../utils/response");
const imagekit_service_1 = require("../services/imagekit.service");
const prisma_1 = __importDefault(require("../lib/prisma"));
async function getProfile(req, res) {
    try {
        const profile = await prisma_1.default.seekerProfile.findUnique({
            where: { userId: req.user.userId },
        });
        (0, response_1.ok)(res, { profile: profile ?? null });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function upsertProfile(req, res) {
    const { firstName, lastName, middleName, age, phone, city, about, searchStatus } = req.body;
    const allowedStatuses = ['ACTIVE', 'OPEN', 'NOT_LOOKING'];
    // Partial update: only include fields that were actually sent
    const updateData = {};
    if (firstName !== undefined)
        updateData['firstName'] = firstName;
    if (lastName !== undefined)
        updateData['lastName'] = lastName;
    if (middleName !== undefined)
        updateData['middleName'] = middleName ?? null;
    if (age !== undefined)
        updateData['age'] = age ? parseInt(age, 10) : null;
    if (phone !== undefined)
        updateData['phone'] = phone ?? null;
    if (city !== undefined)
        updateData['city'] = city ?? null;
    if (about !== undefined)
        updateData['about'] = about ?? null;
    if (searchStatus && allowedStatuses.includes(searchStatus)) {
        updateData['searchStatus'] = searchStatus;
    }
    try {
        const profile = await prisma_1.default.seekerProfile.upsert({
            where: { userId: req.user.userId },
            create: { userId: req.user.userId, firstName: firstName ?? '', lastName: lastName ?? '', ...updateData },
            update: updateData,
        });
        (0, response_1.ok)(res, { profile });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function uploadPhoto(req, res) {
    if (!req.file) {
        (0, response_1.fail)(res, 'No file provided');
        return;
    }
    try {
        const photoUrl = await (0, imagekit_service_1.uploadBuffer)(req.file.buffer, req.file.mimetype, 'ai-job-search/avatars', `seeker-${req.user.userId}-${Date.now()}`);
        const profile = await prisma_1.default.seekerProfile.upsert({
            where: { userId: req.user.userId },
            create: { userId: req.user.userId, firstName: '', lastName: '', photoUrl },
            update: { photoUrl },
        });
        (0, response_1.ok)(res, { photoUrl: profile.photoUrl });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
async function setVisibility(req, res) {
    const { isVisible } = req.body;
    if (typeof isVisible !== 'boolean') {
        (0, response_1.fail)(res, 'isVisible must be a boolean');
        return;
    }
    try {
        const profile = await prisma_1.default.seekerProfile.upsert({
            where: { userId: req.user.userId },
            create: { userId: req.user.userId, firstName: '', lastName: '', isVisible },
            update: { isVisible },
        });
        (0, response_1.ok)(res, { isVisible: profile.isVisible });
    }
    catch (e) {
        (0, response_1.fail)(res, `Server error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
}
