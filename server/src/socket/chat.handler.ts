import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { JwtPayload } from '../types';

export function initChatSocket(io: Server): void {
  io.use((socket, next) => {
    const token = socket.handshake.auth.token as string | undefined;
    if (!token) return next(new Error('Unauthorized'));
    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload;
      (socket as Socket & { user: JwtPayload }).user = payload;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    socket.on('join_application', (applicationId: string) => {
      socket.join(`app_${applicationId}`);
    });

    socket.on('leave_application', (applicationId: string) => {
      socket.leave(`app_${applicationId}`);
    });
  });
}
