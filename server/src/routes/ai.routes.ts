import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth.middleware';
import {
  generateRejectionReason,
  interviewPrep,
  interviewFeedback,
  matchPercent,
  matchVacancies,
  matchResumes,
  coverLetter,
  salaryEstimate,
} from '../controllers/ai.controller';

const router = Router();

router.post('/rejection-reason',  authenticate, requireRole('EMPLOYER'), generateRejectionReason);
router.post('/interview-prep',    authenticate, requireRole('SEEKER'),   interviewPrep);
router.post('/interview-feedback',authenticate, requireRole('SEEKER'),   interviewFeedback);
router.post('/match-percent',     authenticate, requireRole('SEEKER'),   matchPercent);
router.post('/match-vacancies',   authenticate, requireRole('SEEKER'),   matchVacancies);
router.post('/match-resumes',     authenticate, requireRole('EMPLOYER'), matchResumes);
router.post('/cover-letter',      authenticate, requireRole('SEEKER'),   coverLetter);
router.post('/salary-estimate',   authenticate, requireRole('SEEKER'),   salaryEstimate);

export default router;
