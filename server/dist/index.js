"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.httpServer = void 0;
require("dotenv/config");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const http_1 = require("http");
const socket_io_1 = require("socket.io");
const auth_routes_1 = __importDefault(require("./routes/auth.routes"));
const seeker_routes_1 = __importDefault(require("./routes/seeker.routes"));
const employer_routes_1 = __importDefault(require("./routes/employer.routes"));
const resume_routes_1 = __importDefault(require("./routes/resume.routes"));
const chat_routes_1 = __importDefault(require("./routes/chat.routes"));
const ai_routes_1 = __importDefault(require("./routes/ai.routes"));
const skills_routes_1 = __importDefault(require("./routes/skills.routes"));
const boost_routes_1 = __importDefault(require("./routes/boost.routes"));
const vacancy_routes_1 = __importDefault(require("./routes/vacancy.routes"));
const application_routes_1 = __importDefault(require("./routes/application.routes"));
const saved_routes_1 = __importDefault(require("./routes/saved.routes"));
const subscription_routes_1 = __importDefault(require("./routes/subscription.routes"));
const notification_routes_1 = __importDefault(require("./routes/notification.routes"));
const io_1 = require("./lib/io");
const chat_handler_1 = require("./socket/chat.handler");
const app = (0, express_1.default)();
const httpServer = (0, http_1.createServer)(app);
exports.httpServer = httpServer;
const PORT = process.env.PORT ?? 3000;
const io = new socket_io_1.Server(httpServer, {
    cors: { origin: process.env.CLIENT_URL, credentials: true },
});
(0, io_1.setIo)(io);
(0, chat_handler_1.initChatSocket)(io);
app.use((0, cors_1.default)({ origin: process.env.CLIENT_URL, credentials: true }));
app.use(express_1.default.json());
app.use('/api/auth', auth_routes_1.default);
app.use('/api/seeker', seeker_routes_1.default);
app.use('/api/employer', employer_routes_1.default);
app.use('/api/resume', resume_routes_1.default);
app.use('/api/chat', chat_routes_1.default);
app.use('/api/ai', ai_routes_1.default);
app.use('/api/skills/tests', skills_routes_1.default);
app.use('/api/boost', boost_routes_1.default);
app.use('/api/vacancies', vacancy_routes_1.default);
app.use('/api/applications', application_routes_1.default);
app.use('/api/saved', saved_routes_1.default);
app.use('/api/subscriptions', subscription_routes_1.default);
app.use('/api/notifications', notification_routes_1.default);
app.get('/health', (_req, res) => {
    res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});
httpServer.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
