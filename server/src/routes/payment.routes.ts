import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import {
  createPaymePayment,
  paymeCallback,
  createClickPayment,
  clickCallback,
  completeTestPayment,
  getPaymentHistory,
} from '../controllers/payment.controller';

const router = Router();

// Public callbacks from payment systems (no JWT)
router.post('/payme/callback', paymeCallback);
router.post('/click/callback', clickCallback);

// Authenticated routes
router.use(authenticate);
router.post('/payme/create', createPaymePayment);
router.post('/click/create', createClickPayment);
router.post('/test/complete', completeTestPayment);
router.get('/history', getPaymentHistory);

export default router;
