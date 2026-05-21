import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  getSubscriptions,
  createSubscription,
  deleteSubscription,
} from '../controllers/subscription.controller';

const router = Router();

router.use(authenticate, requireRole('SEEKER'));

router.get('/',      getSubscriptions);
router.post('/',     createSubscription);
router.delete('/:id', deleteSubscription);

export default router;
