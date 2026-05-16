# AI Job Search — мобильное приложение (Android / iOS)

## О проекте
Мобильное приложение для поиска работы с ИИ-функциями.
Два типа пользователей: соискатели и работодатели.
Фронтенд: Flutter + Dart.
Бэкенд: Node.js + Express (работает на порту 5000).
Сначала Android, потом iOS.

---

## Стек технологий

### Мобильное приложение (client/) — Flutter
- Flutter + Dart
- go_router (навигация)
- provider (стейт-менеджмент)
- http (API запросы)
- flutter_secure_storage (хранение JWT и настроек)
- image_picker (выбор фото)
- file_picker (выбор PDF)
- flutter_sound (запись голоса)
- flutter_map (карта вакансий)
- printing + pdf (генерация PDF резюме)
- Material Design 3

### Бэкенд (server/) — Node.js
- Node.js + Express + TypeScript
- Prisma ORM + PostgreSQL
- JWT авторизация + Refresh токены
- Socket.io (чат)
- Multer + ImageKit (файлы)
- Groq API: llama-3.3-70b-versatile (текст), whisper-large-v3 (голос)
- helmet.js (безопасность)
- express-rate-limit (защита от брутфорса)
- zod (валидация данных)

---

## Структура проекта Flutter

```
client/
├── lib/
│   ├── main.dart                    # Точка входа, роутер, ThemeProvider
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── seeker/
│   │   │   ├── seeker_dashboard.dart
│   │   │   ├── seeker_profile_screen.dart   # только фото + выбор основного резюме
│   │   │   ├── resume_list_screen.dart
│   │   │   ├── resume_view_screen.dart      # просмотр + редактирование + скачать PDF
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
│   ├── services/
│   │   └── api_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── theme_provider.dart       # глобальная тёмная тема
│   ├── models/
│   └── widgets/
│
└── pubspec.yaml
```

---

## База данных — таблицы

### users
- id, email, password, role (SEEKER | EMPLOYER), createdAt

### seeker_profiles
- id, userId, photoUrl, city
- isVisible, searchStatus (ACTIVE | OPEN | NOT_LOOKING), boostedUntil

### resumes
- id, seekerId, title, content (JSON), pdfUrl, isAiGenerated
- skills (array), experience, aiScore, aiScoreFeedback
- isMain (основное резюме — только одно может быть true)
- createdAt, updatedAt

### skill_tests
- id, seekerId, skill, score, passedAt

### employers
- id, userId, companyName, description, website, logoUrl, city, rating, reviewCount

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

### seeker_analytics
- id, seekerId, resumeViews, applicationsSent, responsesReceived, invitationsReceived

### employer_analytics
- id, employerId, vacancyId, views, applications, invited, hired

### viewed_vacancies
- id, seekerId, vacancyId, viewedAt

### user_badges
- id, userId, badge, earnedAt

### refresh_tokens
- id, userId, token, expiresAt, createdAt

### payments
- id, userId, type (RESUME_BOOST | VACANCY_BOOST), amount, status, createdAt

---

## API роуты (бэкенд)

### Авторизация
- POST /api/auth/register
- POST /api/auth/login
- POST /api/auth/refresh — обновление access токена
- POST /api/auth/logout
- GET /api/auth/me

### Соискатель
- GET/PUT /api/seeker/profile — только фото и searchStatus
- POST /api/seeker/profile/photo
- PUT /api/seeker/profile/search-status

### Резюме
- GET /api/resume
- POST /api/resume/upload
- POST /api/resume/improve
- POST /api/resume/generate/text
- POST /api/resume/generate/voice
- POST /api/resume/:id/score
- GET /api/resume/:id/pdf — скачать PDF
- PUT /api/resume/:id — редактировать резюме
- PUT /api/resume/:id/set-main — установить как основное
- DELETE /api/resume/:id

### Тесты навыков
- GET /api/skills/tests
- POST /api/skills/tests/:skill/submit
- GET /api/skills/results

### Вакансии
- GET /api/vacancies
- GET /api/vacancies/map
- GET /api/vacancies/:id
- GET /api/vacancies/:id/similar
- POST /api/vacancies
- PUT /api/vacancies/:id
- DELETE /api/vacancies/:id

### ИИ-функции
- POST /api/ai/match-vacancies — использует основное резюме (isMain: true)
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

### Чат
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

### Монетизация
- POST /api/boost/resume
- POST /api/boost/vacancy
- GET /api/payments/history

---

## Дизайн

- Основной цвет: синий (#2563EB)
- Акцентный: зелёный (#16A34A)
- Предупреждения: оранжевый (#F97316)
- Фон светлый: #FFFFFF, тёмный: #0F172A
- Material Design 3
- Bottom navigation bar
- Глобальная тёмная тема через ThemeProvider
- Все тексты на русском языке

---

## Переменные окружения

### server/.env
```
DATABASE_URL=postgresql://...
JWT_SECRET=...
JWT_REFRESH_SECRET=...
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d
GROQ_API_KEY=...
IMAGEKIT_URL_ENDPOINT=...
IMAGEKIT_PUBLIC_KEY=...
IMAGEKIT_PRIVATE_KEY=...
PORT=5000
```

### client — API URL в api_service.dart
```dart
static const String baseUrl = 'http://192.168.1.107:5000';
```
⚠️ При деплое заменить на Railway URL

---

## План блоков (текущий статус)

### ✅ Блок 0 — Спринты 1-10 (ГОТОВО)
- Flutter приложение, авторизация JWT
- Профили соискателя и работодателя
- 4 способа создания резюме с ИИ
- Вакансии, карта, фильтры
- ИИ-поиск, % совпадения, зарплата
- Отклики, избранное, уведомления
- Чат Socket.io
- Аналитика, бейджи, рейтинг работодателей
- Тесты навыков, подготовка к интервью
- Тёмная тема, монетизация

### 🔄 Блок 1 — Доделка (В ПРОЦЕССЕ)
- Тёмная тема глобально (не работает)
- Редактирование созданного резюме
- Скачать резюме PDF (missingPluginException)
- Профиль — только фото + выбор основного резюме
- Выбор основного резюме (isMain)

### 📋 Блок 2 — Безопасность
- Rate limiting, Helmet.js, zod валидация
- CORS настройка
- Refresh токены
- Обработка ошибок сети

### 📋 Блок 3 — Производительность
- Пагинация (по 20 штук)
- Кеширование запросов
- Поиск в реальном времени
- Оптимизация изображений

### 📋 Блок 4 — Push-уведомления (FCM)
- Firebase Cloud Messaging
- Новый отклик, просмотр резюме
- Новые вакансии по подписке
- Приглашение на интервью

### 📋 Блок 5 — Email уведомления
- Nodemailer или SendGrid
- Приветственное письмо, отклики, сброс пароля

### 📋 Блок 6 — Модерация и верификация
- Модерация вакансий
- Верификация работодателей
- Жалобы, блокировка спама

### 📋 Блок 7 — Монетизация
- Интеграция Payme (Узбекистан)
- Интеграция Click (Узбекистан)
- История платежей

### 📋 Блок 8 — Админ панель
- Веб-панель администратора
- Управление пользователями и вакансиями
- Статистика платформы
- Модерация жалоб

### 📋 Блок 9 — Политика и документы
- Политика конфиденциальности
- Пользовательское соглашение
- Поддержка пользователей

### 📋 Блок 10 — Деплой и релиз
- Деплой сервера на Railway (HTTPS)
- База данных в облаке (Supabase)
- Сборка APK
- Публикация в Google Play

### 📋 Блок 11 — iOS версия
- Адаптация Flutter под iOS
- Публикация в App Store

---

## Важные заметки для Claude

- Все ИИ-промпты начинать с "Отвечай ТОЛЬКО на русском языке."
- Всегда проверяй роль пользователя (SEEKER/EMPLOYER)
- Groq базовый URL: https://api.groq.com/openai/v1
- Groq модель текст: llama-3.3-70b-versatile
- Groq модель голос: whisper-large-v3
- API URL в Flutter: http://192.168.1.107:5000 (при деплое заменить)
- JWT хранить в flutter_secure_storage
- Refresh токен хранить отдельно в flutter_secure_storage
- ИИ-подбор всегда использует резюме где isMain = true
- Socket.io namespace /chat
- PDF генерировать через printing + pdf пакеты в Flutter
- Профиль соискателя — только фото и выбор основного резюме
- isMain — только одно резюме может быть основным одновременно
- boostedUntil — поднимать в сортировке где boostedUntil > now()
