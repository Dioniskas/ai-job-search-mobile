import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import { listSkillTests, getSkillTestQuestions, submitSkillTest } from '../controllers/skills.controller';

const router = Router();

router.use(authenticate, requireRole('SEEKER'));

router.get('/',              listSkillTests);
router.get('/:skill',        getSkillTestQuestions);
router.post('/:skill/submit', submitSkillTest);

export default router;
