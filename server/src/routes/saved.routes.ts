import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  getSavedVacancies,
  saveVacancy,
  unsaveVacancy,
  checkSavedVacancy,
} from '../controllers/saved.controller';

const router = Router();
router.use(authenticate, requireRole('SEEKER'));

// Static paths before /:vacancyId
router.get('/', getSavedVacancies);
router.get('/:vacancyId/check', checkSavedVacancy);
router.post('/:vacancyId', saveVacancy);
router.delete('/:vacancyId', unsaveVacancy);

export default router;
