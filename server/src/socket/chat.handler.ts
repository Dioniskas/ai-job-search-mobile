import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { JwtPayload } from '../types';

interface SocketWithUser extends Socket {
  data: { user: JwtPayload };
}

export function initChatSocket(io: Server): void {
  io.use((socket, next) => {
    const token = socket.handshake.auth.token as string | undefined;
    if (!token) return next(new Error('Unauthorized'));

    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload;
      (socket as SocketWithUser).data.user = payload;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const s = socket as SocketWithUser;

    s.on('join_application', (applicationId: string) => {
      s.join(`app_${applicationId}`);
    });

    s.on('leave_application', (applicationId: string) => {
      s.leave(`app_${applicationId}`);
    });

    s.on('typing', ({ applicationId }: { applicationId: string }) => {
      s.to(`app_${applicationId}`).emit('typing', { userId: s.data.user.userId });
    });

    s.on('stop_typing', ({ applicationId }: { applicationId: string }) => {
      s.to(`app_${applicationId}`).emit('stop_typing', { userId: s.data.user.userId });
    });
  });
}
