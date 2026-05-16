import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  createAdmin,
  getDashboard,
  getUsers, getUserDetail, blockUser, unblockUser,
  getVacancies, moderateVacancy, rejectVacancy,
  getEmployers, verifyEmployer,
  getReports, resolveReport,
  getPayments,
} from '../controllers/admin.controller';

const router = Router();

// Public — only when no admin exists
router.post('/create-admin', createAdmin);

// Protected — ADMIN only
router.use(authenticate, requireRole('ADMIN'));

router.get('/dashboard', getDashboard);

router.get('/users',          getUsers);
router.get('/users/:id',      getUserDetail);
router.post('/users/:id/block',   blockUser);
router.post('/users/:id/unblock', unblockUser);

router.get('/vacancies',               getVacancies);
router.post('/vacancies/:id/moderate', moderateVacancy);
router.post('/vacancies/:id/reject',   rejectVacancy);

router.get('/employers',              getEmployers);
router.post('/employers/:id/verify',  verifyEmployer);

router.get('/reports',                getReports);
router.post('/reports/:id/resolve',   resolveReport);

router.get('/payments', getPayments);

export default router;
