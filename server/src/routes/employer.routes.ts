import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { uploadSingle } from '../middleware/upload.middleware';
import { getProfile, upsertProfile, uploadLogo } from '../controllers/employer.controller';

const router = Router();

router.use(authenticate, requireRole('EMPLOYER'));

router.get('/profile', getProfile);
router.put('/profile', upsertProfile);
router.post('/profile/logo', uploadSingle('logo'), uploadLogo);

export default router;
