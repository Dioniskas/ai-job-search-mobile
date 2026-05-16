import { z } from 'zod';

export const registerSchema = z.object({
  email:    z.string().email('Некорректный email'),
  password: z.string().min(6, 'Пароль должен быть не менее 6 символов'),
  role:     z.enum(['SEEKER', 'EMPLOYER'], { message: 'role должен быть SEEKER или EMPLOYER' }),
});

export const loginSchema = z.object({
  email:    z.string().email('Некорректный email'),
  password: z.string().min(1, 'Пароль обязателен'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'refreshToken обязателен'),
});

export const createVacancySchema = z.object({
  title:          z.string().min(2, 'Название вакансии обязательно'),
  description:    z.string().min(10, 'Описание должно быть не менее 10 символов'),
  salaryMin:      z.number().int().positive().optional().nullable(),
  salaryMax:      z.number().int().positive().optional().nullable(),
  city:           z.string().optional().nullable(),
  lat:            z.number().optional().nullable(),
  lng:            z.number().optional().nullable(),
  employmentType: z.string().optional().nullable(),
  experience:     z.string().optional().nullable(),
});

export const generateResumeTextSchema = z.object({
  name:       z.string().min(1, 'Имя обязательно'),
  position:   z.string().min(1, 'Должность обязательна'),
  experience: z.string().optional(),
  skills:     z.string().optional(),
  education:  z.string().optional(),
  about:      z.string().optional(),
});
