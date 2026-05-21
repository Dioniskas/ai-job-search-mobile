"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.httpServer = void 0;
require("dotenv/config");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const http_1 = require("http");
const auth_routes_1 = __importDefault(require("./routes/auth.routes"));
const seeker_routes_1 = __importDefault(require("./routes/seeker.routes"));
const employer_routes_1 = __importDefault(require("./routes/employer.routes"));
const resume_routes_1 = __importDefault(require("./routes/resume.routes"));
const resume_controller_1 = require("./controllers/resume.controller");
const vacancy_routes_1 = __importDefault(require("./routes/vacancy.routes"));
const ai_routes_1 = __importDefault(require("./routes/ai.routes"));
const skills_routes_1 = __importDefault(require("./routes/skills.routes"));
const boost_routes_1 = __importDefault(require("./routes/boost.routes"));
const application_routes_1 = __importDefault(require("./routes/application.routes"));
const saved_routes_1 = __importDefault(require("./routes/saved.routes"));
const subscription_routes_1 = __importDefault(require("./routes/subscription.routes"));
const notification_routes_1 = __importDefault(require("./routes/notification.routes"));
const fcm_routes_1 = __importDefault(require("./routes/fcm.routes"));
const chat_routes_1 = __importDefault(require("./routes/chat.routes"));
const email_notifications_routes_1 = __importDefault(require("./routes/email-notifications.routes"));
const admin_routes_1 = __importDefault(require("./routes/admin.routes"));
const report_routes_1 = __importDefault(require("./routes/report.routes"));
const payment_routes_1 = __importDefault(require("./routes/payment.routes"));
const google_auth_routes_1 = __importDefault(require("./routes/google-auth.routes"));
const app = (0, express_1.default)();
const httpServer = (0, http_1.createServer)(app);
exports.httpServer = httpServer;
const PORT = process.env.PORT ?? 5000;
app.set('trust proxy', 1);
// ── CORS — должен быть ПЕРВЫМ до helmet ──────────────────────────────────────
const corsOptions = {
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['Content-Disposition'],
};
app.use((0, cors_1.default)(corsOptions));
app.options('*', (0, cors_1.default)(corsOptions));
// ── Security headers ──────────────────────────────────────────────────────────
app.use((0, helmet_1.default)({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    crossOriginOpenerPolicy: false,
    contentSecurityPolicy: false,
}));
// ── Rate limiting: 100 req/min per IP ────────────────────────────────────────
const limiter = (0, express_rate_limit_1.default)({
    windowMs: 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Слишком много запросов. Попробуйте позже.' },
});
app.use(limiter);
app.use(express_1.default.json({ limit: '2mb' }));
app.use('/api/auth', auth_routes_1.default);
app.use('/api/auth/google', google_auth_routes_1.default);
app.use('/api/seeker', seeker_routes_1.default);
app.use('/api/employer', employer_routes_1.default);
app.use('/api/resume', resume_routes_1.default);
app.use('/api/vacancies', vacancy_routes_1.default);
app.use('/api/ai', ai_routes_1.default);
app.use('/api/skills/tests', skills_routes_1.default);
app.use('/api/boost', boost_routes_1.default);
app.use('/api/applications', application_routes_1.default);
app.use('/api/saved', saved_routes_1.default);
app.use('/api/subscriptions', subscription_routes_1.default);
app.use('/api/notifications', notification_routes_1.default);
app.use('/api/users/fcm-token', fcm_routes_1.default);
app.use('/api/users/email-notifications', email_notifications_routes_1.default);
app.use('/api/chat', chat_routes_1.default);
app.use('/api/admin', admin_routes_1.default);
app.use('/api/reports', report_routes_1.default);
app.use('/api/payments', payment_routes_1.default);
app.get('/health', (_req, res) => {
    res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});
httpServer.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    (0, resume_controller_1.initFonts)();
    const rawDomain = process.env.RAILWAY_PUBLIC_DOMAIN ?? process.env.FRONTEND_URL;
    const pingUrl = rawDomain
        ? rawDomain.startsWith('http')
            ? `${rawDomain}/health`
            : `https://${rawDomain}/health`
        : null;
    if (pingUrl) {
        setInterval(async () => {
            try {
                await fetch(pingUrl);
                console.log('[keep-alive] ping ok');
            }
            catch (e) {
                console.error('[keep-alive] ping failed:', e);
            }
        }, 14 * 60 * 1000);
        console.log(`[keep-alive] pinging ${pingUrl} every 14 min`);
    }
});
