import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { register, login, refresh, logout, me, forgotPassword, resetPassword } from '../controllers/auth.controller';
import { googleMobileAuth, googleCompleteAuth } from '../controllers/google-auth.controller';
import { authenticate } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { registerSchema, loginSchema, refreshSchema } from '../validation/schemas';

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Слишком много попыток входа. Попробуйте через минуту.' },
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Слишком много регистраций с вашего IP. Попробуйте через час.' },
});

const router = Router();

router.post('/register',        registerLimiter, validate(registerSchema), register);
router.post('/login',          loginLimiter,    validate(loginSchema),    login);
router.post('/refresh',                         validate(refreshSchema),  refresh);
router.post('/logout',         authenticate,                              logout);
router.get('/me',              authenticate,                              me);
router.post('/forgot-password', loginLimiter,                             forgotPassword);
router.post('/reset-password',                                            resetPassword);
router.post('/google/mobile',                                             googleMobileAuth);
router.post('/google/complete',                                           googleCompleteAuth);

export default router;
