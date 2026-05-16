import { useEffect, useState } from 'react';
import api from '../api';

interface Stats {
  totalUsers: number;
  totalSeekers: number;
  totalEmployers: number;
  totalVacancies: number;
  activeVacancies: number;
  unmModeratedVacancies: number;
  totalApplications: number;
  totalRevenue: number;
}

interface User {
  id: string;
  email: string;
  role: string;
  isBlocked: boolean;
  createdAt: string;
}

interface Payment {
  id: string;
  type: string;
  amount: number;
  status: string;
  createdAt: string;
  user: { email: string };
}

function fmt(n: number) {
  return n.toLocaleString('ru');
}

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString('ru');
}

function roleBadge(role: string) {
  if (role === 'SEEKER')   return <span className="badge badge-blue">Соискатель</span>;
  if (role === 'EMPLOYER') return <span className="badge badge-orange">Работодатель</span>;
  return <span className="badge badge-gray">Админ</span>;
}

function statusBadge(status: string) {
  if (status === 'PAID')      return <span className="badge badge-green">Оплачен</span>;
  if (status === 'PENDING')   return <span className="badge badge-orange">Ожидание</span>;
  if (status === 'FAILED')    return <span className="badge badge-red">Ошибка</span>;
  return <span className="badge badge-gray">{status}</span>;
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [recentUsers, setRecentUsers] = useState<User[]>([]);
  const [recentPayments, setRecentPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/api/admin/dashboard').then((r) => {
      setStats(r.data.data.stats);
      setRecentUsers(r.data.data.recentUsers);
      setRecentPayments(r.data.data.recentPayments);
    }).finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="loading">Загрузка...</div>;
  if (!stats) return null;

  return (
    <div>
      <div className="page-header">
        <h1>Дашборд</h1>
        <p>Общая статистика платформы</p>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">Всего пользователей</div>
          <div className="stat-value primary">{fmt(stats.totalUsers)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Соискатели</div>
          <div className="stat-value">{fmt(stats.totalSeekers)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Работодатели</div>
          <div className="stat-value">{fmt(stats.totalEmployers)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Вакансии</div>
          <div className="stat-value">{fmt(stats.totalVacancies)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Без модерации</div>
          <div className="stat-value warning">{fmt(stats.unmModeratedVacancies)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Отклики</div>
          <div className="stat-value">{fmt(stats.totalApplications)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Доход (UZS)</div>
          <div className="stat-value success">{fmt(stats.totalRevenue)}</div>
        </div>
      </div>

      <div className="dashboard-grid">
        <div className="card">
          <div className="section-title">Новые пользователи</div>
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Роль</th>
                <th>Дата</th>
              </tr>
            </thead>
            <tbody>
              {recentUsers.map((u) => (
                <tr key={u.id}>
                  <td>{u.email}</td>
                  <td>{roleBadge(u.role)}</td>
                  <td style={{ color: 'var(--text-muted)' }}>{fmtDate(u.createdAt)}</td>
                </tr>
              ))}
              {recentUsers.length === 0 && (
                <tr><td colSpan={3} className="empty">Нет данных</td></tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="card">
          <div className="section-title">Последние платежи</div>
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Тип</th>
                <th>Сумма</th>
                <th>Статус</th>
              </tr>
            </thead>
            <tbody>
              {recentPayments.map((p) => (
                <tr key={p.id}>
                  <td>{p.user.email}</td>
                  <td style={{ fontSize: '12px' }}>{p.type}</td>
                  <td>{fmt(p.amount)}</td>
                  <td>{statusBadge(p.status)}</td>
                </tr>
              ))}
              {recentPayments.length === 0 && (
                <tr><td colSpan={4} className="empty">Нет данных</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
