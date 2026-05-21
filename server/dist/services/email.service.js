"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendWelcomeEmail = sendWelcomeEmail;
exports.sendNewApplicationEmail = sendNewApplicationEmail;
exports.sendApplicationStatusEmail = sendApplicationStatusEmail;
exports.sendInterviewInvitationEmail = sendInterviewInvitationEmail;
exports.sendPasswordResetEmail = sendPasswordResetEmail;
const nodemailer_1 = __importDefault(require("nodemailer"));
const transporter = nodemailer_1.default.createTransport({
    host: process.env.EMAIL_HOST ?? 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_PORT ?? '587', 10),
    secure: false,
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});
const FROM = `"AI Job Search" <${process.env.EMAIL_USER}>`;
function wrap(title, body) {
    return `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:24px;background:#f9fafb;border-radius:8px">
      <div style="background:#2563EB;padding:16px 24px;border-radius:8px 8px 0 0">
        <h1 style="color:#fff;margin:0;font-size:20px">AI Job Search</h1>
      </div>
      <div style="background:#fff;padding:24px;border-radius:0 0 8px 8px">
        <h2 style="color:#1e293b;font-size:18px;margin-top:0">${title}</h2>
        ${body}
        <hr style="border:none;border-top:1px solid #e2e8f0;margin:24px 0"/>
        <p style="color:#94a3b8;font-size:12px;margin:0">AI Job Search — платформа поиска работы</p>
      </div>
    </div>
  `;
}
async function send(to, subject, html) {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS)
        return;
    try {
        await transporter.sendMail({ from: FROM, to, subject, html });
    }
    catch (e) {
        console.error('[email] send error:', e instanceof Error ? e.message : e);
    }
}
// ─── Welcome ──────────────────────────────────────────────────────────────────
async function sendWelcomeEmail(to, name) {
    const html = wrap(`Добро пожаловать, ${name}!`, `<p style="color:#475569">Вы успешно зарегистрировались на платформе <strong>AI Job Search</strong>.</p>
     <p style="color:#475569">Здесь вы найдёте работу своей мечты с помощью искусственного интеллекта.</p>
     <p style="color:#475569">Начните с создания резюме — наш ИИ поможет сделать его привлекательным для работодателей.</p>`);
    await send(to, 'Добро пожаловать в AI Job Search!', html);
}
// ─── New application (to employer) ───────────────────────────────────────────
async function sendNewApplicationEmail(to, seekerName, vacancyTitle) {
    const html = wrap('Новый отклик на вашу вакансию', `<p style="color:#475569">Соискатель <strong>${seekerName}</strong> откликнулся на вакансию <strong>«${vacancyTitle}»</strong>.</p>
     <p style="color:#475569">Войдите в личный кабинет, чтобы просмотреть резюме и принять решение.</p>`);
    await send(to, `Новый отклик: ${vacancyTitle}`, html);
}
// ─── Application status change (to seeker) ───────────────────────────────────
async function sendApplicationStatusEmail(to, vacancyTitle, status) {
    const statusMap = {
        VIEWED: {
            subject: `Ваш отклик просмотрен — ${vacancyTitle}`,
            text: `Работодатель просмотрел ваш отклик на вакансию <strong>«${vacancyTitle}»</strong>.`,
            color: '#2563EB',
        },
        ACCEPTED: {
            subject: `Отклик принят — ${vacancyTitle}`,
            text: `Поздравляем! Ваш отклик на вакансию <strong>«${vacancyTitle}»</strong> принят. Ожидайте приглашения на интервью.`,
            color: '#16A34A',
        },
        REJECTED: {
            subject: `Результат по вакансии — ${vacancyTitle}`,
            text: `К сожалению, ваша кандидатура на вакансию <strong>«${vacancyTitle}»</strong> не подошла. Не расстраивайтесь — ищите дальше!`,
            color: '#F97316',
        },
    };
    const info = statusMap[status];
    if (!info)
        return;
    const html = wrap(info.subject, `<p style="color:#475569">${info.text}</p>`);
    await send(to, info.subject, html);
}
// ─── Interview invitation (to seeker) ────────────────────────────────────────
async function sendInterviewInvitationEmail(to, seekerName, vacancyTitle, companyName) {
    const html = wrap('Приглашение на интервью!', `<p style="color:#475569">Уважаемый(-ая) <strong>${seekerName}</strong>,</p>
     <p style="color:#475569">Компания <strong>${companyName}</strong> приглашает вас на интервью по вакансии <strong>«${vacancyTitle}»</strong>.</p>
     <p style="color:#475569">Войдите в приложение, чтобы уточнить детали в чате с работодателем.</p>`);
    await send(to, `Приглашение на интервью — ${vacancyTitle}`, html);
}
// ─── Password reset ───────────────────────────────────────────────────────────
async function sendPasswordResetEmail(to, token) {
    const frontendUrl = process.env.FRONTEND_URL ?? 'http://localhost:5000';
    const resetUrl = `${frontendUrl}/reset-password?token=${token}`;
    const html = wrap('Сброс пароля', `<p style="color:#475569">Мы получили запрос на сброс пароля для вашей учётной записи.</p>
     <p style="color:#475569">Ваш код сброса пароля:</p>
     <div style="background:#f1f5f9;border-radius:6px;padding:16px;text-align:center;margin:16px 0">
       <code style="font-size:24px;font-weight:bold;letter-spacing:4px;color:#2563EB">${token.slice(0, 8).toUpperCase()}</code>
     </div>
     <p style="color:#475569">Или перейдите по ссылке: <a href="${resetUrl}" style="color:#2563EB">Сбросить пароль</a></p>
     <p style="color:#94a3b8;font-size:13px">Ссылка действительна 1 час. Если вы не запрашивали сброс пароля — проигнорируйте это письмо.</p>`);
    await send(to, 'Сброс пароля — AI Job Search', html);
}
