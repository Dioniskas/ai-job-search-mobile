import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  listVacancies,
  getMapVacancies,
  getEmployerVacancies,
  getVacancy,
  createVacancy,
  updateVacancy,
  deleteVacancy,
  aiVacancyDescription,
  applyToVacancy,
} from '../controllers/vacancy.controller';

const router = Router();

router.use(authenticate);

// Seeker + Employer: read
router.get('/',               listVacancies);
router.get('/map',            getMapVacancies);
router.get('/employer/mine',  requireRole('EMPLOYER'), getEmployerVacancies);
router.get('/:id',            getVacancy);

// Employer only: manage
router.post('/',                      requireRole('EMPLOYER'), createVacancy);
router.post('/ai-description',        requireRole('EMPLOYER'), aiVacancyDescription);
router.patch('/:id',                  requireRole('EMPLOYER'), updateVacancy);
router.delete('/:id',                 requireRole('EMPLOYER'), deleteVacancy);

// Seeker only: apply
router.post('/:id/apply',             requireRole('SEEKER'), applyToVacancy);

export default router;
