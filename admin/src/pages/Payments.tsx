import { useEffect, useState, useCallback } from 'react';
import api from '../api';
import Pagination from '../components/Pagination';

interface Payment {
  id: string;
  type: string;
  provider: string;
  amount: number;
  status: string;
  days: number;
  createdAt: string;
  user: { email: string };
}

const LIMIT = 20;

function statusBadge(status: string) {
  if (status === 'PAID')      return <span className="badge badge-green">Оплачен</span>;
  if (status === 'PENDING')   return <span className="badge badge-orange">Ожидание</span>;
  if (status === 'FAILED')    return <span className="badge badge-red">Ошибка</span>;
  if (status === 'CANCELLED') return <span className="badge badge-gray">Отменён</span>;
  return <span className="badge badge-gray">{status}</span>;
}

function typeLabel(type: string) {
  if (type === 'RESUME_BOOST')  return 'Продвижение резюме';
  if (type === 'VACANCY_BOOST') return 'Продвижение вакансии';
  return type;
}

export default function Payments() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState('');
  const [totalRevenue, setTotalRevenue] = useState(0);
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), limit: String(LIMIT) });
    if (filter) params.set('status', filter);
    api.get(`/api/admin/payments?${params}`).then((r) => {
      setPayments(r.data.data.payments);
      setTotal(r.data.data.total);
      setPages(r.data.data.pages);
      setTotalRevenue(r.data.data.totalRevenue);
    }).finally(() => setLoading(false));
  }, [page, filter]);

  useEffect(() => { load(); }, [load]);

  function handleFilter(v: string) { setFilter(v); setPage(1); }

  return (
    <div>
      <div className="page-header">
        <h1>Платежи</h1>
        <p>История транзакций и статистика доходов</p>
      </div>

      <div className="stats-grid" style={{ marginBottom: 16 }}>
        <div className="stat-card">
          <div className="stat-label">Общий доход (UZS)</div>
          <div className="stat-value success">{totalRevenue.toLocaleString('ru')}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Всего транзакций</div>
          <div className="stat-value">{total}</div>
        </div>
      </div>

      <div className="toolbar">
        <select className="filter-select" value={filter} onChange={(e) => handleFilter(e.target.value)}>
          <option value="">Все статусы</option>
          <option value="PAID">Оплачен</option>
          <option value="PENDING">Ожидание</option>
          <option value="FAILED">Ошибка</option>
          <option value="CANCELLED">Отменён</option>
        </select>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading">Загрузка...</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Пользователь</th>
                  <th>Тип</th>
                  <th>Провайдер</th>
                  <th>Сумма (UZS)</th>
                  <th>Дней</th>
                  <th>Статус</th>
                  <th>Дата</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((p) => (
                  <tr key={p.id}>
                    <td style={{ color: 'var(--text-muted)' }}>{p.user.email}</td>
                    <td style={{ fontSize: 12 }}>{typeLabel(p.type)}</td>
                    <td>
                      <span className="badge badge-blue">{p.provider}</span>
                    </td>
                    <td style={{ fontWeight: 600 }}>{p.amount.toLocaleString('ru')}</td>
                    <td style={{ textAlign: 'center' }}>{p.days}</td>
                    <td>{statusBadge(p.status)}</td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(p.createdAt).toLocaleDateString('ru')}
                    </td>
                  </tr>
                ))}
                {payments.length === 0 && (
                  <tr><td colSpan={7} className="empty">Платежей нет</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
        <Pagination page={page} pages={pages} total={total} limit={LIMIT} onChange={setPage} />
      </div>
    </div>
  );
}
