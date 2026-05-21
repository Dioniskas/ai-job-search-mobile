"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateResumeTextSchema = exports.createVacancySchema = exports.refreshSchema = exports.loginSchema = exports.registerSchema = void 0;
const zod_1 = require("zod");
exports.registerSchema = zod_1.z.object({
    email: zod_1.z.string().email('Некорректный email'),
    password: zod_1.z.string().min(6, 'Пароль должен быть не менее 6 символов'),
    role: zod_1.z.enum(['SEEKER', 'EMPLOYER'], { message: 'role должен быть SEEKER или EMPLOYER' }),
});
exports.loginSchema = zod_1.z.object({
    email: zod_1.z.string().email('Некорректный email'),
    password: zod_1.z.string().min(1, 'Пароль обязателен'),
});
exports.refreshSchema = zod_1.z.object({
    refreshToken: zod_1.z.string().min(1, 'refreshToken обязателен'),
});
exports.createVacancySchema = zod_1.z.object({
    title: zod_1.z.string().min(2, 'Название вакансии обязательно'),
    description: zod_1.z.string().min(10, 'Описание должно быть не менее 10 символов'),
    salaryMin: zod_1.z.number().int().positive().optional().nullable(),
    salaryMax: zod_1.z.number().int().positive().optional().nullable(),
    city: zod_1.z.string().optional().nullable(),
    lat: zod_1.z.number().optional().nullable(),
    lng: zod_1.z.number().optional().nullable(),
    employmentType: zod_1.z.string().optional().nullable(),
    experience: zod_1.z.string().optional().nullable(),
});
exports.generateResumeTextSchema = zod_1.z.object({
    name: zod_1.z.string().min(1, 'Укажите имя и фамилию'),
    experience: zod_1.z.string().min(1, 'Укажите опыт работы'),
    skills: zod_1.z.string().min(1, 'Укажите навыки'),
    age: zod_1.z.string().optional(),
    about: zod_1.z.string().optional(),
});
