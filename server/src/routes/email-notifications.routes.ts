import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import {
  getEmailNotifications,
  updateEmailNotifications,
} from '../controllers/email-notifications.controller';

const router = Router();

router.use(authenticate);
router.get('/',  getEmailNotifications);
router.put('/',  updateEmailNotifications);

export default router;
