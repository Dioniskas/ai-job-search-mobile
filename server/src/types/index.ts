import { Request } from 'express';

export interface JwtPayload {
  userId: string;
  email: string;
  role: 'SEEKER' | 'EMPLOYER';
}

export interface AuthRequest extends Request {
  user?: JwtPayload;
}
