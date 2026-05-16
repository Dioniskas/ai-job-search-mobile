import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { createVacancySchema } from '../validation/schemas';
import {
  listVacancies,
  getMapVacancies,
  getEmployerVacancies,
  aiGenerateDescription,
  getVacancy,
  createVacancy,
  updateVacancy,
  deleteVacancy,
  applyToVacancy,
} from '../controllers/vacancy.controller';

const router = Router();

// Static paths MUST come before /:id
router.get('/map',           authenticate, getMapVacancies);
router.get('/employer/mine', authenticate, requireRole('EMPLOYER'), getEmployerVacancies);
router.post('/ai-description', authenticate, requireRole('EMPLOYER'), aiGenerateDescription);

// Collection
router.get('/',  authenticate, listVacancies);
router.post('/', authenticate, requireRole('EMPLOYER'), validate(createVacancySchema), createVacancy);

// Item
router.get('/:id',         authenticate, getVacancy);
router.patch('/:id',       authenticate, requireRole('EMPLOYER'), updateVacancy);
router.delete('/:id',      authenticate, requireRole('EMPLOYER'), deleteVacancy);
router.post('/:id/apply',  authenticate, requireRole('SEEKER'), applyToVacancy);

export default router;
