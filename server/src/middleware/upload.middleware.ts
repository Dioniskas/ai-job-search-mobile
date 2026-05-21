import multer from 'multer';
import { Request, Response, NextFunction } from 'express';
import { fail } from '../utils/response';

const storage = multer.memoryStorage();

function makeUploader(allowedMime: string[], maxMb: number) {
  return multer({
    storage,
    limits: { fileSize: maxMb * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      if (allowedMime.includes(file.mimetype)) {
        cb(null, true);
      } else {
        cb(new Error(`Allowed types: ${allowedMime.join(', ')}`));
      }
    },
  });
}

const imageUploader = makeUploader(['image/jpeg', 'image/png', 'image/webp'], 5);
const pdfUploader   = makeUploader(['application/pdf'], 10);
const audioUploader = makeUploader(
  ['audio/webm', 'audio/ogg', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'video/webm'],
  25
);

function wrapSingle(uploader: multer.Multer, fieldName: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    uploader.single(fieldName)(req, res, (err) => {
      if (err instanceof multer.MulterError) {
        fail(res, `Upload error: ${err.message}`);
      } else if (err instanceof Error) {
        fail(res, err.message);
      } else {
        next();
      }
    });
  };
}

export const uploadSingle = (field: string) => wrapSingle(imageUploader, field);
export const uploadPdf    = (field: string) => wrapSingle(pdfUploader, field);
export const uploadAudio  = (field: string) => wrapSingle(audioUploader, field);
