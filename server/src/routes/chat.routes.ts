import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { getConversations, getMessages, sendMessage } from '../controllers/chat.controller';

const router = Router();
router.use(authenticate);

router.get('/conversations',              getConversations);
router.get('/:applicationId/messages',   getMessages);
router.post('/:applicationId/messages',  sendMessage);

export default router;
