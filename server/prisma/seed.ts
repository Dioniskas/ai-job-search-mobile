import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const CITIES = ['Ташкент', 'Самарканд', 'Бухара', 'Фергана', 'Андижан', 'Намangan'];

const EMPLOYMENT_TYPES = ['FULL_TIME', 'PART_TIME', 'CONTRACT', 'INTERNSHIP'];

const employers = [
  {
    email: 'restoran@test.com',
    companyName: 'Сеть ресторанов "Дастархан"',
    description: 'Крупнейшая сеть ресторанов узбекской кухни в Ташкенте. Работаем с 2010 года, 12 филиалов по всему городу.',
    website: 'https://dasturxon.uz',
    city: 'Ташкент',
  },
  {
    email: 'itcompany@test.com',
    companyName: 'TechUz Solutions',
    description: 'IT-компания по разработке мобильных и веб-приложений. Работаем с клиентами из Узбекистана, России и Европы.',
    website: 'https://techuz.dev',
    city: 'Ташкент',
  },
  {
    email: 'logistics@test.com',
    companyName: 'ЛогистикаПро',
    description: 'Транспортная и логистическая компания. Доставка грузов по всему Узбекистану и СНГ.',
    website: 'https://logpro.uz',
    city: 'Самарканд',
  },
];

const vacanciesData = [
  // ── Ресторанная сфера ────────────────────────────────────────────────────
  {
    employerIndex: 0,
    title: 'Шеф-повар',
    description: 'Ищем опытного шеф-повара для нашего флагманского ресторана. Опыт работы с узбекской и восточной кухней обязателен. Управление кухней, составление меню, обучение персонала.',
    salaryMin: 3_000_000,
    salaryMax: 5_000_000,
    city: 'Ташкент',
    lat: 41.2995,
    lng: 69.2401,
    employmentType: 'FULL_TIME',
    experience: '5+ лет',
  },
  {
    employerIndex: 0,
    title: 'Повар горячего цеха',
    description: 'Приготовление блюд узбекской кухни: плов, шашлык, лагман, самса. График 2/2. Питание за счёт заведения.',
    salaryMin: 1_800_000,
    salaryMax: 2_500_000,
    city: 'Ташкент',
    lat: 41.3111,
    lng: 69.2797,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 0,
    title: 'Официант',
    description: 'Обслуживание гостей, знание меню, работа с кассой. Обучаем с нуля. Хорошие чаевые. График 5/2.',
    salaryMin: 1_200_000,
    salaryMax: 1_800_000,
    city: 'Самарканд',
    lat: 39.6547,
    lng: 66.9758,
    employmentType: 'FULL_TIME',
    experience: 'Без опыта',
  },
  {
    employerIndex: 0,
    title: 'Администратор ресторана',
    description: 'Управление персоналом зала, работа с гостями, решение конфликтных ситуаций, контроль работы смены.',
    salaryMin: 2_000_000,
    salaryMax: 3_000_000,
    city: 'Ташкент',
    lat: 41.2830,
    lng: 69.2167,
    employmentType: 'FULL_TIME',
    experience: '3+ года',
  },
  {
    employerIndex: 0,
    title: 'Кондитер',
    description: 'Приготовление десертов, выпечки, тортов на заказ. Знание современных кондитерских техник. Работа в кондитерском цехе.',
    salaryMin: 1_500_000,
    salaryMax: 2_200_000,
    city: 'Бухара',
    lat: 39.7747,
    lng: 64.4286,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  // ── IT сфера ─────────────────────────────────────────────────────────────
  {
    employerIndex: 1,
    title: 'Flutter разработчик',
    description: 'Разработка мобильных приложений на Flutter/Dart. Знание Provider/Bloc, REST API, Firebase. Участие в полном цикле разработки.',
    salaryMin: 5_000_000,
    salaryMax: 10_000_000,
    city: 'Ташкент',
    lat: 41.3123,
    lng: 69.2787,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 1,
    title: 'Backend разработчик (Node.js)',
    description: 'Разработка REST API на Node.js/Express, работа с PostgreSQL, Redis. Знание TypeScript обязательно. Возможна удалёнка.',
    salaryMin: 6_000_000,
    salaryMax: 12_000_000,
    city: 'Ташкент',
    lat: 41.2956,
    lng: 69.2314,
    employmentType: 'FULL_TIME',
    experience: '3+ года',
  },
  {
    employerIndex: 1,
    title: 'UI/UX Дизайнер',
    description: 'Проектирование интерфейсов мобильных и веб-приложений. Figma, Adobe XD, знание принципов Material Design и Human Interface Guidelines.',
    salaryMin: 4_000_000,
    salaryMax: 7_000_000,
    city: 'Ташкент',
    lat: 41.3067,
    lng: 69.2406,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 1,
    title: 'Frontend разработчик (React)',
    description: 'Разработка веб-интерфейсов на React/TypeScript. Знание Next.js, Tailwind CSS, работа с REST/GraphQL API.',
    salaryMin: 4_500_000,
    salaryMax: 9_000_000,
    city: 'Ташкент',
    lat: 41.3201,
    lng: 69.2590,
    employmentType: 'CONTRACT',
    experience: '2+ года',
  },
  {
    employerIndex: 1,
    title: 'Junior Python разработчик',
    description: 'Разработка скриптов автоматизации, парсеров, простых API на FastAPI/Django. Отличная возможность для начинающих.',
    salaryMin: 2_500_000,
    salaryMax: 4_000_000,
    city: 'Ташкент',
    lat: 41.2889,
    lng: 69.2156,
    employmentType: 'FULL_TIME',
    experience: '0–1 год',
  },
  {
    employerIndex: 1,
    title: 'Менеджер проектов (IT)',
    description: 'Управление командой разработчиков, планирование спринтов, работа с заказчиками. Scrum/Agile, Jira, знание английского B2+.',
    salaryMin: 5_000_000,
    salaryMax: 8_000_000,
    city: 'Ташкент',
    lat: 41.2995,
    lng: 69.2350,
    employmentType: 'FULL_TIME',
    experience: '3+ года',
  },
  {
    employerIndex: 1,
    title: 'DevOps инженер',
    description: 'Настройка CI/CD, Docker, Kubernetes, AWS/GCP. Поддержка инфраструктуры, мониторинг, обеспечение SLA.',
    salaryMin: 7_000_000,
    salaryMax: 14_000_000,
    city: 'Ташкент',
    lat: 41.3045,
    lng: 69.2478,
    employmentType: 'FULL_TIME',
    experience: '4+ года',
  },
  {
    employerIndex: 1,
    title: 'Графический дизайнер',
    description: 'Создание визуального контента для соцсетей, баннеров, полиграфии. Adobe Photoshop, Illustrator. Интересные проекты.',
    salaryMin: 2_000_000,
    salaryMax: 4_000_000,
    city: 'Фергана',
    lat: 40.3834,
    lng: 71.7870,
    employmentType: 'PART_TIME',
    experience: '1+ год',
  },
  // ── Логистика ────────────────────────────────────────────────────────────
  {
    employerIndex: 2,
    title: 'Водитель-экспедитор (категория B/C)',
    description: 'Доставка грузов по Узбекистану. Опыт вождения от 3 лет, чистые права, знание города. Топливо и ТО за счёт компании.',
    salaryMin: 2_500_000,
    salaryMax: 4_000_000,
    city: 'Самарканд',
    lat: 39.6270,
    lng: 66.9750,
    employmentType: 'FULL_TIME',
    experience: '3+ года',
  },
  {
    employerIndex: 2,
    title: 'Логист (менеджер по логистике)',
    description: 'Планирование маршрутов, работа с перевозчиками, оформление документов. Знание 1С, Excel. Опыт в транспортной сфере.',
    salaryMin: 3_000_000,
    salaryMax: 5_000_000,
    city: 'Самарканд',
    lat: 39.6547,
    lng: 66.9758,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 2,
    title: 'Кладовщик',
    description: 'Приём, хранение и отпуск товарно-материальных ценностей. Работа со складской программой. График 6/1.',
    salaryMin: 1_500_000,
    salaryMax: 2_200_000,
    city: 'Андижан',
    lat: 40.7821,
    lng: 72.3442,
    employmentType: 'FULL_TIME',
    experience: '1+ год',
  },
  {
    employerIndex: 2,
    title: 'Менеджер по продажам',
    description: 'Поиск клиентов, ведение переговоров, заключение договоров на логистические услуги. Оклад + % от продаж.',
    salaryMin: 2_000_000,
    salaryMax: 6_000_000,
    city: 'Намangan',
    lat: 41.0011,
    lng: 71.6725,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 2,
    title: 'Продавец-консультант',
    description: 'Консультирование клиентов, оформление заказов, работа с кассой. Торговля запчастями для грузовых автомобилей.',
    salaryMin: 1_500_000,
    salaryMax: 2_500_000,
    city: 'Бухара',
    lat: 39.7671,
    lng: 64.4559,
    employmentType: 'FULL_TIME',
    experience: '1+ год',
  },
  {
    employerIndex: 2,
    title: 'Бухгалтер',
    description: 'Ведение первичной документации, расчёт зарплаты, работа с банком. Знание 1С:Бухгалтерия обязательно.',
    salaryMin: 2_500_000,
    salaryMax: 4_000_000,
    city: 'Самарканд',
    lat: 39.6600,
    lng: 66.9800,
    employmentType: 'FULL_TIME',
    experience: '3+ года',
  },
  {
    employerIndex: 2,
    title: 'HR-менеджер',
    description: 'Подбор персонала, адаптация новых сотрудников, ведение кадрового делопроизводства. Опыт работы в крупной компании.',
    salaryMin: 2_500_000,
    salaryMax: 3_500_000,
    city: 'Ташкент',
    lat: 41.3012,
    lng: 69.2370,
    employmentType: 'FULL_TIME',
    experience: '2+ года',
  },
  {
    employerIndex: 1,
    title: 'Стажёр-разработчик (оплачиваемая стажировка)',
    description: 'Трёхмесячная оплачиваемая стажировка для студентов и выпускников IT-специальностей. Менторство, реальные задачи, возможность трудоустройства.',
    salaryMin: 1_000_000,
    salaryMax: 1_500_000,
    city: 'Ташкент',
    lat: 41.3156,
    lng: 69.2521,
    employmentType: 'INTERNSHIP',
    experience: 'Без опыта',
  },
];

async function main() {
  console.log('🌱 Начинаем заполнение базы данных...');

  // Очистка в правильном порядке (зависимости)
  await prisma.notification.deleteMany();
  await prisma.message.deleteMany();
  await prisma.application.deleteMany();
  await prisma.vacancy.deleteMany();
  await prisma.employer.deleteMany();
  await prisma.skillTest.deleteMany();
  await prisma.resume.deleteMany();
  await prisma.vacancySubscription.deleteMany();
  await prisma.savedVacancy.deleteMany();
  await prisma.seekerProfile.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();

  console.log('✅ База очищена');

  const passwordHash = await bcrypt.hash('password123', 10);

  // ── Создаём работодателей ──────────────────────────────────────────────
  const createdEmployers: { id: string }[] = [];

  for (const emp of employers) {
    const user = await prisma.user.create({
      data: {
        email: emp.email,
        password: passwordHash,
        role: 'EMPLOYER',
        employerProfile: {
          create: {
            companyName: emp.companyName,
            description: emp.description,
            website: emp.website,
            city: emp.city,
          },
        },
      },
      include: { employerProfile: true },
    });
    createdEmployers.push({ id: user.employerProfile!.id });
    console.log(`  ✅ Работодатель: ${emp.companyName} (${emp.email})`);
  }

  // ── Создаём вакансии ───────────────────────────────────────────────────
  let vacancyCount = 0;
  for (const v of vacanciesData) {
    await prisma.vacancy.create({
      data: {
        employerId:     createdEmployers[v.employerIndex].id,
        title:          v.title,
        description:    v.description,
        salaryMin:      v.salaryMin,
        salaryMax:      v.salaryMax,
        city:           v.city,
        lat:            v.lat,
        lng:            v.lng,
        employmentType: v.employmentType,
        experience:     v.experience,
        isActive:       true,
      },
    });
    vacancyCount++;
    console.log(`  ✅ Вакансия: ${v.title} — ${v.city}`);
  }

  // ── Создаём тестового соискателя ───────────────────────────────────────
  const seeker = await prisma.user.create({
    data: {
      email: 'seeker@test.com',
      password: passwordHash,
      role: 'SEEKER',
      seekerProfile: {
        create: {
          firstName: 'Алишер',
          lastName: 'Каримов',
          city: 'Ташкент',
          about: 'Ищу работу программиста или аналитика данных.',
          searchStatus: 'ACTIVE',
        },
      },
    },
  });
  console.log(`  ✅ Соискатель: ${seeker.email}`);

  console.log('\n🎉 Готово!');
  console.log(`   Работодателей: ${createdEmployers.length}`);
  console.log(`   Вакансий:      ${vacancyCount}`);
  console.log(`   Соискателей:   1`);
  console.log('\n📧 Тестовые аккаунты (пароль для всех: password123):');
  console.log('   restoran@test.com   — Дастархан (ресторан)');
  console.log('   itcompany@test.com  — TechUz Solutions (IT)');
  console.log('   logistics@test.com  — ЛогистикаПро (логистика)');
  console.log('   seeker@test.com     — Алишер Каримов (соискатель)');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
