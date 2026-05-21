import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import authRoutes from './routes/auth.routes';
import seekerRoutes from './routes/seeker.routes';
import employerRoutes from './routes/employer.routes';
import resumeRoutes from './routes/resume.routes';
import chatRoutes from './routes/chat.routes';
import aiRoutes from './routes/ai.routes';
import skillsRoutes from './routes/skills.routes';
import boostRoutes from './routes/boost.routes';
import vacancyRoutes from './routes/vacancy.routes';
import applicationRoutes from './routes/application.routes';
import savedRoutes from './routes/saved.routes';
import subscriptionRoutes from './routes/subscription.routes';
import notificationRoutes from './routes/notification.routes';
import { setIo } from './lib/io';
import { initChatSocket } from './socket/chat.handler';

const app = express();
const httpServer = createServer(app);
const PORT = process.env.PORT ?? 3000;

const io = new Server(httpServer, {
  cors: { origin: process.env.CLIENT_URL, credentials: true },
});
setIo(io);
initChatSocket(io);

app.use(cors({ origin: process.env.CLIENT_URL, credentials: true }));
app.use(express.json());

app.use('/api/auth',          authRoutes);
app.use('/api/seeker',        seekerRoutes);
app.use('/api/employer',      employerRoutes);
app.use('/api/resume',        resumeRoutes);
app.use('/api/chat',          chatRoutes);
app.use('/api/ai',            aiRoutes);
app.use('/api/skills/tests',  skillsRoutes);
app.use('/api/boost',         boostRoutes);
app.use('/api/vacancies',     vacancyRoutes);
app.use('/api/applications',  applicationRoutes);
app.use('/api/saved',         savedRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/notifications', notificationRoutes);

app.get('/health', (_req, res) => {
  res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});

httpServer.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

export { httpServer };
