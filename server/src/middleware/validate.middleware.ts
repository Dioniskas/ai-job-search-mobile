import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { fail } from '../utils/response';

export function validate(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const error = (result.error as ZodError).errors[0];
      fail(res, error.message, 400);
      return;
    }
    req.body = result.data;
    next();
  };
}
