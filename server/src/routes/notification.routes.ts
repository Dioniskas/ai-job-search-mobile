import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import {
  getNotifications,
  markNotificationsRead,
} from '../controllers/notification.controller';

const router = Router();

router.use(authenticate);

router.get('/',         getNotifications);
router.patch('/read',   markNotificationsRead);

export default router;
