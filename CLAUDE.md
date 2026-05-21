# AI Job Search — аналог HH.ru с искусственным интеллектом

## О проекте
Платформа для поиска работы с ИИ-функциями. Два типа пользователей: соискатели и работодатели.
ИИ помогает соискателям создавать резюме, находить подходящие вакансии и готовиться к интервью.
ИИ помогает работодателям находить подходящих кандидатов и создавать вакансии.

---

## Стек технологий

### Фронтенд
- React + TypeScript
- Tailwind CSS
- React Router v6
- Axios (HTTP-запросы)
- React Hook Form (формы)
- Zustand (стейт-менеджмент)
- Socket.io-client (чат в реальном времени)
- React-Leaflet (карта вакансий)

### Бэкенд
- Node.js + Express
- TypeScript
- Prisma ORM
- JWT (авторизация)
- Multer (загрузка файлов)
- pdf-parse (чтение PDF резюме)
- Socket.io (чат в реальном времени)

### База данных
- PostgreSQL

### Внешние сервисы
- Groq API: llama-3.3-70b-versatile (текст), whisper-large-v3 (голос)
- ImageKit: хранение фото и PDF резюме

---

## Структура проекта

```
/
├── client/                      # Фронтенд (React)
│   ├── src/
│   │   ├── components/          # Переиспользуемые компоненты
│   │   │   ├── ui/              # Базовые UI компоненты
│   │   │   ├── chat/            # Компоненты чата
│   │   │   ├── resume/          # Компоненты резюме
│   │   │   └── vacancy/         # Компоненты вакансий
│   │   ├── pages/
│   │   │   ├── auth/            # Авторизация
│   │   │   ├── seeker/          # Страницы соискателя
│   │   │   ├── employer/        # Страницы работодателя
│   │   │   └── public/          # Публичные страницы
│   │   ├── store/               # Zustand store
│   │   ├── hooks/               # Кастомные хуки
│   │   ├── services/            # API-вызовы
│   │   ├── types/               # TypeScript типы
│   │   └── utils/               # Утилиты
│
├── server/                      # Бэкенд (Node.js)
│   ├── src/
│   │   ├── routes/              # Роуты API
│   │   ├── controllers/         # Контроллеры
│   │   ├── middleware/          # Middleware
│   │   ├── services/
│   │   │   └── ai/              # ИИ-сервисы (Groq)
│   │   ├── socket/              # Socket.io
│   │   ├── prisma/              # Схема БД
│   │   └── utils/
│
└── CLAUDE.md
```

---

## База данных — таблицы

### users
- id, email, password, role (SEEKER | EMPLOYER), createdAt

### seeker_profiles
- id, userId, firstName, lastName, middleName, age, phone, city, photoUrl, about
- isVisible, searchStatus (ACTIVE | OPEN | NOT_LOOKING)
- boostedUntil

### resumes
- id, seekerId, title, content (JSON), pdfUrl, isAiGenerated
- skills (array), experience, aiScore (оценка ИИ от 1 до 10), aiScoreFeedback
- createdAt, updatedAt

### skill_tests
- id, seekerId, skill, score, passedAt

### employers
- id, userId, companyName, description, website, logoUrl, city
- rating (средний рейтинг), reviewCount

### employer_reviews
- id, seekerId, employerId, rating (1-5), comment, createdAt

### vacancies
- id, employerId, title, description, salaryMin, salaryMax
- city, lat, lng, employmentType, experience
- isActive, boostedUntil, viewCount, createdAt

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
- id, seekerId, resumeViews, applicationsSent, responsesReceived, invitationsReceived, updatedAt

### employer_analytics
- id, employerId, vacancyId, views, applications, invited, hired, updatedAt

### viewed_vacancies
- id, seekerId, vacancyId, viewedAt

### user_badges
- id, userId, badge, earnedAt

---

## API роуты

### Авторизация
- POST /api/auth/register
- POST /api/auth/login
- GET /api/auth/me

### Соискатель
- GET/PUT /api/seeker/profile
- POST /api/seeker/profile/photo
- PUT /api/seeker/profile/visibility
- PUT /api/seeker/profile/search-status

### Резюме
- GET /api/resume
- POST /api/resume/upload — загрузить PDF
- POST /api/resume/improve — ИИ улучшает PDF
- POST /api/resume/generate/text — ИИ из формы
- POST /api/resume/generate/voice — ИИ из голоса
- POST /api/resume/:id/score — ИИ оценивает резюме (1-10)
- PUT /api/resume/:id
- DELETE /api/resume/:id

### Тесты навыков
- GET /api/skills/tests
- POST /api/skills/tests/:skill/start
- POST /api/skills/tests/:skill/submit
- GET /api/skills/results

### Вакансии
- GET /api/vacancies — с фильтрами
- GET /api/vacancies/map — для карты
- GET /api/vacancies/:id — одна вакансия + похожие
- GET /api/vacancies/:id/similar — похожие вакансии
- POST /api/vacancies
- PUT /api/vacancies/:id
- DELETE /api/vacancies/:id
- GET /api/vacancies/:id/stats

### Избранное и подписки
- POST/DELETE /api/saved/:vacancyId
- GET /api/saved
- GET /api/history — история просмотренных вакансий
- POST/GET/DELETE /api/subscriptions

### ИИ-функции
- POST /api/ai/match-vacancies — подбор вакансий под резюме
- POST /api/ai/match-resumes — подбор резюме под вакансию
- POST /api/ai/cover-letter — сопроводительное письмо
- POST /api/ai/match-percent — % совпадения
- POST /api/ai/interview-prep — вопросы для интервью
- POST /api/ai/interview-feedback — оценка ответа
- POST /api/ai/vacancy-generate — генерация текста вакансии
- POST /api/ai/salary-estimate — оценка рыночной зарплаты по резюме
- POST /api/ai/rejection-reason — вежливая причина отказа
- POST /api/ai/vacancy-hints — подсказки при создании вакансии

### Отклики
- POST /api/applications
- GET /api/applications/seeker
- GET /api/applications/employer
- PUT /api/applications/:id/status
- PUT /api/applications/:id/viewed

### Чат (+ Socket.io)
- GET /api/chat/conversations
- GET /api/chat/:applicationId/messages
- POST /api/chat/:applicationId/messages

### Уведомления
- GET /api/notifications
- PUT /api/notifications/:id/read
- PUT /api/notifications/read-all

### Аналитика
- GET /api/analytics/seeker — дашборд соискателя
- GET /api/analytics/employer/:vacancyId — воронка найма
- GET /api/analytics/market/:profession — рыночная статистика по профессии

### Работодатель
- GET/PUT /api/employer/profile
- POST /api/employer/profile/logo
- POST /api/employer/reviews — оставить отзыв о компании
- GET /api/employer/:id/reviews — отзывы о компании

### Монетизация
- POST /api/boost/resume
- POST /api/boost/vacancy

---

## ИИ-функции (подробно)

### Все ИИ-промпты начинаются с:
"Отвечай ТОЛЬКО на русском языке."

### 1. Загрузка PDF → извлечение текста (pdf-parse)
### 2. Улучшение резюме (Groq GPT)
### 3. Генерация резюме из формы

Структура резюме как на HH.ru:
- Название (желаемая должность)
- О себе (2-3 предложения, сильные стороны)
- Опыт работы (обратный хронологический порядок: компания, должность, период, обязанности, достижения с цифрами)
- Образование (учебное заведение, специальность, год)
- Ключевые навыки (профессиональные, конкретные)
- Иностранные языки (уровень CEFR)
- Дополнительная информация

### 4. Генерация из голоса (Whisper → Groq)
### 5. Оценка резюме (1-10 + конкретные советы что улучшить)
### 6. % совпадения резюме с вакансией
### 7. Подбор вакансий под резюме (до 30 вакансий за раз)
### 8. Подбор резюме под вакансию (до 30 резюме за раз)
### 9. Сопроводительное письмо
### 10. Подготовка к интервью + оценка ответов
### 11. Оценка рыночной зарплаты по резюме
### 12. Генерация текста вакансии с подсказками
### 13. Вежливая причина отказа кандидату

---

## Переменные окружения (server/.env)

```
DATABASE_URL=postgresql://...
JWT_SECRET=...
JWT_EXPIRES_IN=7d
GROQ_API_KEY=...
IMAGEKIT_URL_ENDPOINT=...
IMAGEKIT_PUBLIC_KEY=...
IMAGEKIT_PRIVATE_KEY=...
PORT=5000
CLIENT_URL=http://localhost:3000
```

---

## Дизайн

- Стиль: чистый, современный, светлая тема + тёмная тема
- Основной цвет: синий (#2563EB)
- Акцентный: зелёный (#16A34A)
- Предупреждения: оранжевый (#F97316)
- Шрифт: Inter или system-ui
- Компоненты: карточки с тенью, rounded-xl
- Адаптивность: mobile-first
- Прогресс-бар заполненности профиля

---

## Соглашения по коду

- TypeScript везде, строгая типизация
- Компоненты React — функциональные
- Стили — только Tailwind CSS
- try/catch везде
- API ответы: { success: boolean, data?: any, error?: string }
- JWT в Authorization: Bearer <token>
- ИИ-запросы — в server/src/services/ai/
- Socket.io namespace /chat

---

## План спринтов

### ✅ Спринт 1 — Фундамент (ГОТОВО)
- Структура проекта, БД, авторизация, JWT, 2 роли

### ✅ Спринт 2 — Профили (ГОТОВО)
- Профили соискателя и работодателя, фото через ImageKit

### ✅ Спринт 3 — Резюме с ИИ (ГОТОВО)
- 4 способа создания резюме, Groq API, Whisper

### 📋 Спринт 4 — Вакансии
- Создание вакансий, ИИ-генерация текста, список с фильтрами
- Страница вакансии + похожие вакансии
- Карта вакансий, статистика просмотров

### 📋 Спринт 5 — ИИ-поиск и совпадения
- % совпадения резюме с вакансией
- ИИ-подбор вакансий / резюме
- Сопроводительное письмо
- Оценка резюме от ИИ (1-10)
- Оценка рыночной зарплаты

### 📋 Спринт 6 — Отклики и взаимодействие
- Система откликов, быстрый отклик в 1 клик
- Статус просмотра резюме
- Избранные вакансии, история просмотров
- Автопоиск (подписки)
- Уведомления в реальном времени
- Статус поиска работы (активно / рассматриваю / не ищу)

### 📋 Спринт 7 — Чат
- Чат Socket.io, история, уведомления
- Шаблоны сообщений для работодателя
- Вежливый отказ через ИИ

### 📋 Спринт 8 — Аналитика и геймификация
- Дашборд соискателя (отклики, просмотры, график)
- Дашборд работодателя (воронка найма)
- Статистика рынка (средняя зарплата по профессии)
- Прогресс-бар заполненности профиля
- Бейджи (Опытный специалист, Быстро отвечает и др.)
- Рейтинг и отзывы о работодателях

### 📋 Спринт 9 — Дополнительные фичи
- Тесты на подтверждение навыков
- ИИ-подготовка к интервью
- Видео-визитка соискателя
- Подсказки ИИ при создании вакансии
- Тёмная тема
- Монетизация (поднятие резюме/вакансий)

### 📋 Спринт 10 — Финал
- Полировка дизайна, мобильная адаптация
- Обработка всех edge-cases
- Финальное тестирование

---

## Важные заметки для Claude

- Все ИИ-промпты начинать с "Отвечай ТОЛЬКО на русском языке."
- Всегда проверяй роль пользователя (SEEKER/EMPLOYER) в middleware
- Groq базовый URL: https://api.groq.com/openai/v1
- Groq модель текст: llama-3.3-70b-versatile
- Groq модель голос: whisper-large-v3
- Голосовые записи — временные файлы, удалять после Whisper
- При ИИ-подборе передавай не более 30 записей за раз
- Socket.io namespace /chat для чата
- Уведомления: онлайн → Socket.io, офлайн → только БД
- viewCount вакансии увеличивать при GET (кроме самого работодателя)
- boostedUntil — при сортировке поднимать записи где boostedUntil > now()
- searchStatus соискателя показывать работодателям в карточке резюме
- Похожие вакансии — по совпадению профессии и города
