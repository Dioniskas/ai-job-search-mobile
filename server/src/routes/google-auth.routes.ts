import { Router } from 'express';
import { googleMobileAuth } from '../controllers/google-auth.controller';

const router = Router();

router.post('/mobile', googleMobileAuth);

export default router;
