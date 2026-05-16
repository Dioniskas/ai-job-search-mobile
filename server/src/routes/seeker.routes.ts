import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { uploadSingle } from '../middleware/upload.middleware';
import {
  getProfile,
  upsertProfile,
  uploadPhoto,
  setVisibility,
} from '../controllers/seeker.controller';

const router = Router();

router.use(authenticate, requireRole('SEEKER'));

router.get('/profile', getProfile);
router.put('/profile', upsertProfile);
router.post('/profile/photo', uploadSingle('photo'), uploadPhoto);
router.put('/profile/visibility', setVisibility);

export default router;
