# AI Job Search — мобильное приложение (Android / iOS)

---

## Роль и поведение Claude Code

Ты — сеньор full-stack разработчик с 10+ лет опыта.
Специализация: Flutter/Dart (мобильные приложения) + Node.js/TypeScript (бэкенд).

**Принципы работы:**
- Пишешь чистый, читаемый, production-ready код
- Всегда обрабатываешь ошибки и edge cases
- Следуешь архитектуре проекта, не изобретаешь новую
- Перед изменением файла — читаешь его полностью
- После каждой задачи: `git add . && git commit -m "..." && git push origin master`
- Не спрашиваешь лишнего — выполняешь задачу
- Если что-то непонятно — делаешь по аналогии с существующим кодом

**Автономная работа с ошибками:**
1. Читаешь полный текст ошибки
2. Находишь причину самостоятельно
3. Исправляешь без запроса разрешения
4. Проверяешь что исправление не сломало другое
5. Только если не можешь решить за 3 попытки — сообщаешь о проблеме
Никогда не останавливаешься на ошибке. Всегда ищешь решение.

---

## О проекте
Мобильное приложение для поиска работы с ИИ-функциями.
Два типа пользователей: соискатели и работодатели.
Фронтенд: Flutter + Dart.
Бэкенд: Node.js + Express (задеплоен на Railway).
База данных: PostgreSQL на Supabase.
Сначала Android, потом iOS.

---

## Рабочий процесс (Claude Code)

В начале каждой сессии:
1. `clear` — очистить терминал
2. `cd C:\Projects\ai-job-search-mobile` — перейти в папку проекта
3. Запустить `claude` и написать `caveman`
4. Claude Code читает CLAUDE.md и продолжает с текущего блока

После каждой задачи: `git add . && git commit -m "..." && git push origin master`

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
- google_sign_in: ^6.2.1 (Google OAuth)
- permission_handler (разрешения микрофон/камера)
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
- google-auth-library (Google OAuth верификация)

---

## Деплой

### Бэкенд
- Railway: https://ai-job-search-mobile-production.up.railway.app
- БД: Supabase PostgreSQL
- Node.js версия: 20 (NIXPACKS_NODE_VERSION=20)

### Мобильное приложение
- APK: client/build/app/outputs/flutter-apk/app-release.apk
- API URL: https://ai-job-search-mobile-production.up.railway.app
- baseUrl в client/lib/services/api_service.dart = Railway URL (production режим)

---

## Структура проекта Flutter

```
client/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart         # Google Sign In добавлен
│   │   │   ├── register_screen.dart
│   │   │   └── role_select_screen.dart   # Выбор роли после Google OAuth
│   │   ├── seeker/
│   │   │   ├── seeker_shell.dart         # Bottom nav: Поиск/Карьера/Отклики/Сообщения/Профиль
│   │   │   ├── home_screen.dart          # Вкладка "Карьера" — ИИ подбор, аналитика
│   │   │   ├── search_screen.dart        # Вкладка "Поиск" — вакансии
│   │   │   ├── profile_screen.dart       # Профиль + резюме + настройки
│   │   │   ├── resume_screen.dart        # Список резюме
│   │   │   ├── resume_create_screen.dart # 6-шаговая форма создания резюме
│   │   │   ├── resume_detail_screen.dart # Просмотр с фото + кнопки
│   │   │   ├── resume_edit_screen.dart   # Редактирование
│   │   │   ├── vacancy_detail_screen.dart
│   │   │   ├── applications_screen.dart  # Отклики с фильтрами + отмена
│   │   │   ├── ai_match_screen.dart
│   │   │   ├── interview_prep_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   └── chat_screen.dart
│   │   ├── employer/
│   │   │   ├── employer_shell.dart
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
│   │   ├── auth_provider.dart            # loginWithGoogle + completeGoogleAuth
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
- id, userId, firstName, lastName, middleName, age, phone
- photoUrl, city, about
- isVisible, searchStatus (ACTIVE | OPEN | NOT_LOOKING), boostedUntil

### resumes
- id, seekerId, title, content (JSON), pdfUrl, photoUrl
- isAiGenerated, isMain, skills (array), experience
- createdAt, updatedAt

### employers
- id, userId, companyName, description, website, logoUrl, city
- isVerified

### vacancies
- id, employerId, title, description, salaryMin, salaryMax
- city, lat, lng, employmentType, experience
- isActive, isModerated, boostedUntil, viewCount, createdAt

### applications
- id, resumeId, vacancyId, seekerId, employerId
- status (PENDING | VIEWED | ACCEPTED | REJECTED)
- coverLetter, matchPercent, createdAt

### messages, notifications, saved_vacancies, refresh_tokens
### reports, payments, vacancy_subscriptions
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
- POST /api/auth/google/mobile (проверка токена, isNewUser flow)
- POST /api/auth/google/complete (создание аккаунта с ролью)

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
- POST /api/resume/:id/photo
- DELETE /api/resume/:id

### Вакансии
- GET /api/vacancies (с пагинацией page/limit)
- GET /api/vacancies/map
- GET /api/vacancies/:id
- GET /api/vacancies/:id/similar
- POST /api/vacancies
- PUT /api/vacancies/:id
- DELETE /api/vacancies/:id

### Отклики
- GET /api/applications
- POST /api/applications
- DELETE /api/applications/:id (только PENDING, только свой)

### ИИ-функции (везде "Ассистент" в UI)
- POST /api/ai/match-vacancies
- POST /api/ai/match-resumes
- POST /api/ai/cover-letter
- POST /api/ai/match-percent
- POST /api/ai/interview-prep
- POST /api/ai/interview-feedback
- POST /api/ai/vacancy-generate
- POST /api/ai/salary-estimate
- POST /api/ai/rejection-reason
- POST /api/ai/vacancy-hints

### Остальные роуты
- /api/applications, /api/chat, /api/notifications
- /api/analytics, /api/employer, /api/admin
- /api/reports, /api/boost, /api/payments
- /api/users/fcm-token, /api/users/email-notifications

---

## Google OAuth конфигурация (АКТУАЛЬНО)

- Firebase проект: ai-job-search-a184d (НОВЫЙ!)
- Google Cloud проект: ai-job-search-a184d
- Web Client ID: [see Railway env GOOGLE_CLIENT_ID]
- Android Client ID (debug): [see google-services.json]
- Android Client ID (release): [see google-services.json]
- SHA-1 debug: F8:5D:A4:47:83:15:B6:A8:DA:BB:D3:BE:C7:9E:D7:24:43:52:9B:67
- SHA-1 release: 4E:65:0E:28:4B:67:87:30:35:99:24:43:C9:6E:DC:9E:C9:3C:11:35
- GOOGLE_CLIENT_ID (Railway): [set in Railway env vars]
- ✅ Google OAuth работает на release APK

---

## Переменные окружения (server/.env и Railway)

```
DATABASE_URL=postgresql://postgres.morniwpjfhgkpqnanpny:[PASSWORD]@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1&prepared_statements=false
DIRECT_URL=postgresql://postgres.morniwpjfhgkpqnanpny:[PASSWORD]@aws-1-ap-south-1.pooler.supabase.com:5432/postgres
JWT_SECRET=[JWT_SECRET]
JWT_REFRESH_SECRET=[JWT_REFRESH_SECRET]
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d
PORT=5000
NIXPACKS_NODE_VERSION=20
GROQ_API_KEY=...
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/dioniskas
IMAGEKIT_PUBLIC_KEY=...
IMAGEKIT_PRIVATE_KEY=...
FIREBASE_PROJECT_ID=ai-job-search-a184d
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=den7026960@gmail.com
EMAIL_PASS=...
GOOGLE_CLIENT_ID=[your-google-client-id]
GOOGLE_CLIENT_SECRET=[your-google-client-secret]
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

## Дизайн (стиль hh.ru + Material 3)

- Основной цвет: синий (#2563EB)
- Акцентный: зелёный (#16A34A)
- Предупреждения: оранжевый (#F97316)
- Фон светлый: #F2F2F7, тёмный: #000000
- Карточки светлые: белые, тёмные: #1C1C1E
- Bottom nav светлый: белый, тёмный: #1C1C1E
- Material Design 3, скругления 14-16px
- Глобальная тёмная тема через ThemeProvider ✅
- Все тексты на русском языке
- "ИИ" заменён на "Ассистент" везде в UI

---

## Статус блоков

### ✅ Блок 1 — Доделка (ГОТОВО)
### ✅ Блок 2 — Безопасность (ГОТОВО)
### ✅ Блок 3 — Производительность (ГОТОВО)
### ✅ Блок 4 — Push-уведомления (ГОТОВО)
### ✅ Блок 5 — Email уведомления (ГОТОВО)
### ✅ Блок 6 — Модерация и верификация (ГОТОВО)
### ✅ Блок 7 — Монетизация (ГОТОВО)
### ✅ Блок 8 — Админ панель (ГОТОВО)
### ✅ Блок 9 — Политика и документы (ГОТОВО)

### ✅ Блок 10 — Деплой и релиз (ГОТОВО)
- ✅ Supabase БД настроена и мигрирована
- ✅ Railway деплой работает, Node.js 20
- ✅ APK собирается и работает на телефоне
- ✅ CORS исправлен
- ✅ ImageKit работает
- ✅ Google OAuth работает (release APK)
- ✅ Голосовой ввод работает
- ⚠️ Connection pool timeout — нужен retry или Supabase Pro

### 🔄 Блок 11 — Редизайн под hh.ru (В ПРОЦЕССЕ)
- ✅ Material 3 тема обновлена
- ✅ Bottom navigation переделан (5 вкладок как hh.ru)
- ✅ Форма резюме — 6 шагов
- ✅ Кнопки резюме переделаны
- ✅ Фото резюме — загрузка работает
- ✅ Отмена отклика работает
- 🔄 Поиск — карточки вакансий как hh.ru
- 🔄 Детальная вакансия — редизайн
- 🔄 Отклики — фильтры по статусу
- 🔄 Профиль — редизайн как hh.ru
- ❌ PDF резюме — кириллица (шрифт скачивается при старте)

### 📋 Блок 12 — Google OAuth ✅ ГОТОВО
### 📋 Блок 13 — Голосовой ввод ✅ ГОТОВО

### 📋 Блок 14 — Локализация (Узбекский язык)
- flutter_localizations
- Переключатель: Русский / O'zbekcha

### 📋 Блок 15 — iOS версия
- Адаптация Flutter под iOS
- Публикация в App Store

---

## Текущие задачи редизайна (приоритет)

1. 🔄 search_screen.dart — карточки вакансий как hh.ru
2. 🔄 vacancy_detail_screen.dart — полный редизайн
3. 🔄 applications_screen.dart — фильтры по статусу
4. 🔄 profile_screen.dart — редизайн как hh.ru + меню настроек
5. ⚠️ PDF резюме — проверить кириллицу после деплоя

---

## Важные заметки для Claude Code

- Все ИИ-промпты начинать с "Отвечай ТОЛЬКО на русском языке."
- В UI писать "Ассистент" вместо "ИИ"
- Groq базовый URL: https://api.groq.com/openai/v1
- Groq модель текст: llama-3.3-70b-versatile
- Groq модель голос: whisper-large-v3
- JWT хранить в flutter_secure_storage
- ИИ-подбор использует резюме где isMain = true
- Socket.io namespace /chat
- isMain — только одно резюме может быть основным
- Новые вакансии только если isModerated = true
- trust proxy 1 в index.ts для Railway
- Админ: den7026960@gmail.com / [PASSWORD]
- GitHub: https://github.com/Dioniskas/ai-job-search-mobile
- Railway root directory: server/
- Keystore: client/android/app/aijobsearch.keystore (пароль: aijobsearch123)
- Без keystore нельзя обновить APK в Google Play
