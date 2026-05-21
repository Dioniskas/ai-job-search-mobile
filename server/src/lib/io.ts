import { Server } from 'socket.io';

let io: Server;

export function setIo(instance: Server): void {
  io = instance;
}

export function getIo(): Server {
  if (!io) throw new Error('Socket.io not initialized');
  return io;
}
