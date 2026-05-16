import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  aiMatchPercent,
  aiMatchVacancies,
  aiMatchResumes,
  aiCoverLetter,
  aiSalaryEstimate,
  aiInterviewPrep,
  aiInterviewFeedback,
} from '../controllers/ai.controller';

const router = Router();

router.use(authenticate);

router.post('/interview-prep',     requireRole('SEEKER'), aiInterviewPrep);
router.post('/interview-feedback', requireRole('SEEKER'), aiInterviewFeedback);
router.post('/match-percent',      aiMatchPercent);
router.post('/match-vacancies',    aiMatchVacancies);
router.post('/match-resumes',      aiMatchResumes);
router.post('/cover-letter',       aiCoverLetter);
router.post('/salary-estimate',    aiSalaryEstimate);

export default router;
