"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient({
    datasources: {
        db: {
            url: process.env.DATABASE_URL,
        },
    },
});
prisma.$use(async (params, next) => {
    const MAX_RETRIES = 3;
    const RETRY_DELAY_MS = 2000;
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        try {
            return await next(params);
        }
        catch (err) {
            if (err?.code === 'P2024' && attempt < MAX_RETRIES) {
                await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
                continue;
            }
            throw err;
        }
    }
});
exports.default = prisma;
