import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  getSeekerApplications,
  getEmployerApplications,
  updateApplicationStatus,
} from '../controllers/application.controller';

const router = Router();

router.use(authenticate);

router.get('/seeker',     requireRole('SEEKER'),   getSeekerApplications);
router.get('/employer',   requireRole('EMPLOYER'),  getEmployerApplications);
router.patch('/:id/status', requireRole('EMPLOYER'), updateApplicationStatus);

export default router;
