# AI Job Search — мобильное приложение (Android / iOS)

## О проекте
Мобильное приложение для поиска работы с ИИ-функциями.
Два типа пользователей: соискатели и работодатели.
Фронтенд: Flutter + Dart.
Бэкенд: Node.js + Express (задеплоен на Railway).
База данных: PostgreSQL на Supabase.
Сначала Android, потом iOS.

---

## Стек технологий

### Мобильное приложение (client/) — Flutter
- Flutter + Dart
- go_router (навигация)
- provider (стейт-менеджмент)
- http (API запросы)
- flutter_secure_storage (хранение JWT)
- image_picker (выбор фото)
- file_picker (выбор PDF)
- flutter_sound (запись голоса)
- flutter_map (карта вакансий)
- printing + pdf (генерация PDF резюме)
- cached_network_image (кеширование изображений)
- firebase_messaging (push-уведомления)
- Material Design 3

### Бэкенд (server/) — Node.js
- Node.js + Express + TypeScript
- Prisma ORM + PostgreSQL (Supabase)
- JWT авторизация + Refresh токены
- Socket.io (чат)
- Multer + ImageKit (файлы)
- Groq API: llama-3.3-70b-versatile (текст), whisper-large-v3 (голос)
- helmet.js, express-rate-limit, zod
- nodemailer (email)
- firebase-admin (push-уведомления)

---

## Деплой

### Бэкенд
- Railway: https://ai-job-search-mobile-production.up.railway.app
- БД: Supabase PostgreSQL

### Мобильное приложение
- APK собран: client/build/app/outputs/flutter-apk/app-release.apk
- API URL в api_service.dart: https://ai-job-search-mobile-production.up.railway.app

---

## Структура проекта Flutter

```
client/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── seeker/
│   │   │   ├── seeker_dashboard.dart
│   │   │   ├── seeker_profile_screen.dart
│   │   │   ├── resume_list_screen.dart
│   │   │   ├── resume_view_screen.dart
│   │   │   ├── resume_edit_screen.dart
│   │   │   ├── vacancy_search_screen.dart
│   │   │   ├── vacancy_detail_screen.dart
│   │   │   ├── applications_screen.dart
│   │   │   ├── ai_match_screen.dart
│   │   │   ├── interview_prep_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   └── chat_screen.dart
│   │   ├── employer/
│   │   │   ├── employer_dashboard.dart
│   │   │   ├── employer_profile_screen.dart
│   │   │   ├── vacancy_list_screen.dart
│   │   │   ├── vacancy_create_screen.dart
│   │   │   ├── candidates_screen.dart
│   │   │   ├── applications_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   └── chat_screen.dart
│   │   └── shared/
│   │       ├── map_screen.dart
│   │       └── notifications_screen.dart
│   ├── services/api_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── theme_provider.dart
│   ├── models/
│   └── widgets/
│
└── pubspec.yaml
```

---

## База данных (Supabase)

### users
- id, email, password, role (SEEKER | EMPLOYER | ADMIN)
- fcmToken, isBlocked (default false)
- emailNotifications (JSONB)
- passwordResetToken, passwordResetExpires
- createdAt

### seeker_profiles
- id, userId, photoUrl, city
- isVisible, searchStatus (ACTIVE | OPEN | NOT_LOOKING), boostedUntil

### resumes
- id, seekerId, title, content (JSON), pdfUrl, isAiGenerated
- skills (array), experience, aiScore, aiScoreFeedback
- isMain (основное резюме)
- createdAt, updatedAt

### employers
- id, userId, companyName, description, website, logoUrl, city
- rating, reviewCount, isVerified

### employer_reviews
- id, seekerId, employerId, rating (1-5), comment, createdAt

### vacancies
- id, employerId, title, description, salaryMin, salaryMax
- city, lat, lng, employmentType, experience
- isActive, isModerated, boostedUntil, viewCount, createdAt

### applications
- id, resumeId, vacancyId, seekerId, employerId
- status (PENDING | VIEWED | ACCEPTED | REJECTED)
- coverLetter, matchPercent, createdAt

### messages
- id, senderId, receiverId, applicationId, text, isRead, createdAt

### notifications
- id, userId, type, text, isRead, link, createdAt

### saved_vacancies
- id, seekerId, vacancyId, createdAt

### vacancy_subscriptions
- id, seekerId, query, city, salaryMin, employmentType, createdAt

### refresh_tokens
- id, userId, token, expiresAt, createdAt

### reports
- id, reporterId, targetId, targetType, reason, isResolved, createdAt

### payments
- id, userId, type, amount, status, createdAt

### seeker_analytics, employer_analytics, viewed_vacancies, user_badges, skill_tests

---

## API роуты

### Авторизация
- POST /api/auth/register (role: SEEKER | EMPLOYER)
- POST /api/auth/login
- POST /api/auth/refresh
- POST /api/auth/logout
- GET /api/auth/me
- POST /api/auth/forgot-password
- POST /api/auth/reset-password

### Соискатель
- GET/PUT /api/seeker/profile
- POST /api/seeker/profile/photo
- PUT /api/seeker/profile/search-status

### Резюме
- GET /api/resume
- POST /api/resume/upload
- POST /api/resume/improve
- POST /api/resume/generate/text
- POST /api/resume/generate/voice
- POST /api/resume/:id/score
- GET /api/resume/:id/pdf
- PUT /api/resume/:id
- PUT /api/resume/:id/set-main
- DELETE /api/resume/:id

### Вакансии
- GET /api/vacancies (с пагинацией page/limit)
- GET /api/vacancies/map
- GET /api/vacancies/:id
- GET /api/vacancies/:id/similar
- POST /api/vacancies
- PUT /api/vacancies/:id
- DELETE /api/vacancies/:id

### ИИ-функции
- POST /api/ai/match-vacancies (использует isMain резюме)
- POST /api/ai/match-resumes
- POST /api/ai/cover-letter
- POST /api/ai/match-percent
- POST /api/ai/interview-prep
- POST /api/ai/interview-feedback
- POST /api/ai/vacancy-generate
- POST /api/ai/salary-estimate
- POST /api/ai/rejection-reason
- POST /api/ai/vacancy-hints

### Отклики
- POST /api/applications
- GET /api/applications/seeker
- GET /api/applications/employer
- PUT /api/applications/:id/status
- PUT /api/applications/:id/viewed

### Чат + Socket.io
- GET /api/chat/conversations
- GET /api/chat/:applicationId/messages
- POST /api/chat/:applicationId/messages

### Уведомления
- GET /api/notifications
- PUT /api/notifications/:id/read
- PUT /api/notifications/read-all

### Аналитика
- GET /api/analytics/seeker
- GET /api/analytics/employer/:vacancyId
- GET /api/analytics/market/:profession

### Работодатель
- GET/PUT /api/employer/profile
- POST /api/employer/profile/logo
- POST /api/employer/reviews
- GET /api/employer/:id/reviews

### Модерация (Admin)
- POST /api/admin/vacancies/:id/moderate
- POST /api/admin/employers/:id/verify
- POST /api/admin/users/:id/block
- POST /api/admin/create-admin

### Жалобы
- POST /api/reports

### Монетизация
- POST /api/boost/resume
- POST /api/boost/vacancy
- GET /api/payments/history
- POST /api/payments/payme/create (тестовый режим)
- POST /api/payments/click/create (тестовый режим)

### Push-уведомления
- POST /api/users/fcm-token

### Email настройки
- PUT /api/users/email-notifications

---

## Переменные окружения (server/.env и Railway)

```
DATABASE_URL=postgresql://...pooler...6543...?pgbouncer=true&connection_limit=1
DIRECT_URL=postgresql://...session pooler...5432...
JWT_SECRET=den7026960
JWT_REFRESH_SECRET=den7026960_refresh_secret_change_in_prod
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d
PORT=5000
GROQ_API_KEY=...
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/dioniskas
IMAGEKIT_PUBLIC_KEY=...
IMAGEKIT_PRIVATE_KEY=...
FIREBASE_PROJECT_ID=ai-job-search-70a97
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=den7026960@gmail.com
EMAIL_PASS=...
FRONTEND_URL=https://ai-job-search-mobile-production.up.railway.app
CLIENT_URL=https://ai-job-search-mobile-production.up.railway.app
PAYME_MERCHANT_ID=test
PAYME_SECRET_KEY=test
PAYME_TEST_MODE=true
CLICK_SERVICE_ID=test
CLICK_MERCHANT_ID=test
CLICK_SECRET_KEY=test
CLICK_TEST_MODE=true
```

---

## Дизайн

- Основной цвет: синий (#2563EB)
- Акцентный: зелёный (#16A34A)
- Предупреждения: оранжевый (#F97316)
- Фон светлый: #FFFFFF, тёмный: #0F172A
- Material Design 3, Bottom navigation bar
- Глобальная тёмная тема через ThemeProvider
- Все тексты на русском языке

---

## Статус блоков

### ✅ Блок 1 — Доделка (ГОТОВО)
- Редактирование резюме, скачать PDF, профиль упрощён, выбор основного резюме

### ✅ Блок 2 — Безопасность (ГОТОВО)
- Rate limiting, Helmet.js, zod, CORS, refresh токены, обработка ошибок

### ✅ Блок 3 — Производительность (ГОТОВО)
- Пагинация, бесконечная прокрутка, кеширование, debounce поиск, cached_network_image

### ✅ Блок 4 — Push-уведомления (ГОТОВО)
- Firebase FCM, уведомления при откликах, сообщениях, изменении статуса

### ✅ Блок 5 — Email уведомления (ГОТОВО)
- Nodemailer, Gmail SMTP, приветствие, отклики, сброс пароля

### ✅ Блок 6 — Модерация и верификация (ГОТОВО)
- Модерация вакансий, верификация работодателей, жалобы, блокировка

### ✅ Блок 7 — Монетизация (ГОТОВО)
- Payme и Click (тестовый режим), поднятие резюме/вакансий, история платежей

### ✅ Блок 8 — Админ панель (ГОТОВО)
- React веб-панель на localhost:3001, вход через ADMIN роль
- Дашборд, пользователи, вакансии, верификация, жалобы, платежи

### ✅ Блок 9 — Политика и документы (ГОТОВО)
- Политика конфиденциальности, пользовательское соглашение, поддержка

### 🔄 Блок 10 — Деплой и релиз (В ПРОЦЕССЕ)
- ✅ Supabase БД настроена и мигрирована
- ✅ Railway деплой настроен
- ✅ APK собран
- ❌ APK не работает — ошибка 502 при входе (проблема с колонками в Supabase)
- Текущая проблема: добавляем недостающие колонки в Supabase через SQL Editor

### 📋 Блок 11 — Локализация (Узбекский язык)
- flutter_localizations
- Переключатель язык: Русский / O'zbekcha
- Все тексты и ИИ промпты на узбекском

### 📋 Блок 12 — iOS версия
- Адаптация Flutter под iOS
- Публикация в App Store

---

## Текущие проблемы (требуют решения)

1. APK выдаёт 502 при входе — в Supabase не хватает колонок
2. Тёмная тема не работает глобально (только профиль и резюме)
3. Карта вакансий не работает (отложено)
4. Тестовые вакансии не созданы (seed не выполнен)
5. Нужно сменить все ключи API (они были показаны в открытом чате)

---

## Важные заметки для Claude

- Все ИИ-промпты начинать с "Отвечай ТОЛЬКО на русском языке."
- Groq базовый URL: https://api.groq.com/openai/v1
- Groq модель текст: llama-3.3-70b-versatile
- Groq модель голос: whisper-large-v3
- API URL Flutter: https://ai-job-search-mobile-production.up.railway.app
- JWT хранить в flutter_secure_storage
- ИИ-подбор использует резюме где isMain = true
- Socket.io namespace /chat
- PDF генерировать через printing + pdf в Flutter
- Профиль соискателя: только фото + выбор основного резюме + настройки
- isMain — только одно резюме может быть основным
- Новые вакансии показываются только если isModerated = true
- trust proxy 1 добавлен в index.ts для Railway
- Админ: den7026960@gmail.com / den58354037
- GitHub: https://github.com/Dioniskas/ai-job-search-mobile
- Railway root directory: server/
- Keystore для APK сохранён — без него нельзя обновить приложение в Google Play
