import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { boostResume, boostVacancy, getBoostStatus } from '../controllers/boost.controller';

const router = Router();

router.use(authenticate);

router.get('/status',  getBoostStatus);
router.post('/resume',  requireRole('SEEKER'),   boostResume);
router.post('/vacancy', requireRole('EMPLOYER'),  boostVacancy);

export default router;
