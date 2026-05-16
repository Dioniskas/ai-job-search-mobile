import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { saveFcmToken, deleteFcmToken } from '../controllers/fcm.controller';

const router = Router();
router.use(authenticate);

router.post('/',   saveFcmToken);
router.delete('/', deleteFcmToken);

export default router;
