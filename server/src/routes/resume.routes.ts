import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { uploadPdf, uploadAudio, uploadSingle } from '../middleware/upload.middleware';
import { validate } from '../middleware/validate.middleware';
import { generateResumeTextSchema } from '../validation/schemas';
import {
  getResumes,
  uploadPdf as uploadPdfCtrl,
  improvePdf,
  generateFromText,
  generateFromVoice,
  updateResume,
  deleteResume,
  scoreResumeCtrl,
  generateResumePdf,
  setMainResume,
  uploadResumePhoto,
} from '../controllers/resume.controller';

const router = Router();

router.use(authenticate, requireRole('SEEKER'));

router.get('/',                        getResumes);
router.post('/upload',                 uploadPdf('pdf'),   uploadPdfCtrl);
router.post('/improve',                uploadPdf('pdf'),   improvePdf);
router.post('/generate/text',          validate(generateResumeTextSchema), generateFromText);
router.post('/generate/voice',         uploadAudio('audio'), generateFromVoice);
router.get('/:id/pdf',                 generateResumePdf);
router.post('/:id/score',              scoreResumeCtrl);
router.put('/:id/main',                setMainResume);
router.put('/:id',                     updateResume);
router.delete('/:id',                  deleteResume);
router.post('/:id/photo', uploadSingle('photo'), uploadResumePhoto);


export default router;
