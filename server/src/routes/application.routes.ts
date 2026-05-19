import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  createApplication,
  getSeekerApplications,
  getEmployerApplications,
  updateApplicationStatus,
  deleteApplication,
} from '../controllers/application.controller';

const router = Router();
router.use(authenticate);

router.post('/',                requireRole('SEEKER'),   createApplication);
router.get('/seeker',           requireRole('SEEKER'),   getSeekerApplications);
router.get('/employer',         requireRole('EMPLOYER'),  getEmployerApplications);
router.patch('/:id/status',     requireRole('EMPLOYER'),  updateApplicationStatus);
router.delete('/:id',           requireRole('SEEKER'),    deleteApplication);

export default router;
