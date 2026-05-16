import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import authRoutes from './routes/auth.routes';
import seekerRoutes from './routes/seeker.routes';
import employerRoutes from './routes/employer.routes';
import resumeRoutes from './routes/resume.routes';
import vacancyRoutes from './routes/vacancy.routes';
import aiRoutes from './routes/ai.routes';
import skillsRoutes from './routes/skills.routes';
import boostRoutes from './routes/boost.routes';
import applicationRoutes from './routes/application.routes';
import savedRoutes from './routes/saved.routes';
import subscriptionRoutes from './routes/subscription.routes';
import notificationRoutes from './routes/notification.routes';
import fcmRoutes from './routes/fcm.routes';
import chatRoutes from './routes/chat.routes';
import emailNotificationsRoutes from './routes/email-notifications.routes';
import adminRoutes from './routes/admin.routes';
import reportRoutes from './routes/report.routes';
import paymentRoutes from './routes/payment.routes';

const app = express();
const httpServer = createServer(app);
const PORT = process.env.PORT ?? 5000;

// ── Security headers ──────────────────────────────────────────────────────────
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' }, // allow images from ImageKit
}));

// ── Rate limiting: 100 req/min per IP ────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Слишком много запросов. Попробуйте позже.' },
});
app.use(limiter);

// ── CORS ──────────────────────────────────────────────────────────────────────
// Mobile clients connect from real devices with no fixed origin,
// so we allow all origins in dev. Restrict to a domain in production via CLIENT_URL env.
const allowedOrigin = process.env.CLIENT_URL;
app.use(cors({
  origin: allowedOrigin ? allowedOrigin : true,
  credentials: true,
}));

app.use(express.json({ limit: '2mb' }));

app.use('/api/auth',          authRoutes);
app.use('/api/seeker',        seekerRoutes);
app.use('/api/employer',      employerRoutes);
app.use('/api/resume',        resumeRoutes);
app.use('/api/vacancies',     vacancyRoutes);
app.use('/api/ai',            aiRoutes);
app.use('/api/skills/tests',  skillsRoutes);
app.use('/api/boost',         boostRoutes);
app.use('/api/applications',  applicationRoutes);
app.use('/api/saved',         savedRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/users/fcm-token',            fcmRoutes);
app.use('/api/users/email-notifications',  emailNotificationsRoutes);
app.use('/api/chat',                       chatRoutes);
app.use('/api/admin',                      adminRoutes);
app.use('/api/reports',                    reportRoutes);
app.use('/api/payments',                   paymentRoutes);

app.get('/health', (_req, res) => {
  res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});

httpServer.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export { httpServer };
