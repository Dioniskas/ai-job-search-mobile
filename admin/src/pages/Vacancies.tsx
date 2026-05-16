import { useEffect, useState, useCallback } from 'react';
import api from '../api';
import Pagination from '../components/Pagination';

interface Vacancy {
  id: string;
  title: string;
  city?: string;
  isActive: boolean;
  isModerated: boolean;
  createdAt: string;
  employer: { companyName: string; isVerified: boolean };
  _count: { applications: number };
}

const LIMIT = 20;

export default function Vacancies() {
  const [vacancies, setVacancies] = useState<Vacancy[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState('false'); // default: unmoderated
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), limit: String(LIMIT) });
    if (filter !== '') params.set('moderated', filter);
    api.get(`/api/admin/vacancies?${params}`).then((r) => {
      setVacancies(r.data.data.vacancies);
      setTotal(r.data.data.total);
      setPages(r.data.data.pages);
    }).finally(() => setLoading(false));
  }, [page, filter]);

  useEffect(() => { load(); }, [load]);

  function handleFilter(v: string) { setFilter(v); setPage(1); }

  async function approve(id: string) {
    await api.post(`/api/admin/vacancies/${id}/moderate`);
    load();
  }

  async function reject(id: string) {
    await api.post(`/api/admin/vacancies/${id}/reject`);
    load();
  }

  return (
    <div>
      <div className="page-header">
        <h1>Вакансии</h1>
        <p>Модерация вакансий работодателей</p>
      </div>

      <div className="toolbar">
        <select className="filter-select" value={filter} onChange={(e) => handleFilter(e.target.value)}>
          <option value="false">Ожидают модерации</option>
          <option value="true">Одобренные</option>
          <option value="">Все</option>
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
                  <th>Название</th>
                  <th>Компания</th>
                  <th>Город</th>
                  <th>Отклики</th>
                  <th>Статус</th>
                  <th>Дата</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {vacancies.map((v) => (
                  <tr key={v.id}>
                    <td style={{ fontWeight: 500 }}>{v.title}</td>
                    <td>
                      {v.employer.companyName}
                      {v.employer.isVerified && (
                        <span style={{ marginLeft: 4, color: 'var(--success)' }}>✓</span>
                      )}
                    </td>
                    <td style={{ color: 'var(--text-muted)' }}>{v.city ?? '—'}</td>
                    <td style={{ textAlign: 'center' }}>{v._count.applications}</td>
                    <td>
                      {!v.isActive
                        ? <span className="badge badge-red">Отклонена</span>
                        : v.isModerated
                          ? <span className="badge badge-green">Одобрена</span>
                          : <span className="badge badge-orange">На модерации</span>}
                    </td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(v.createdAt).toLocaleDateString('ru')}
                    </td>
                    <td>
                      <div className="btn-actions">
                        {!v.isModerated && v.isActive && (
                          <>
                            <button className="btn btn-sm btn-success" onClick={() => approve(v.id)}>
                              Одобрить
                            </button>
                            <button className="btn btn-sm btn-danger" onClick={() => reject(v.id)}>
                              Отклонить
                            </button>
                          </>
                        )}
                        {v.isModerated && v.isActive && (
                          <button className="btn btn-sm btn-danger" onClick={() => reject(v.id)}>
                            Снять
                          </button>
                        )}
                        {!v.isActive && (
                          <button className="btn btn-sm btn-success" onClick={() => approve(v.id)}>
                            Восстановить
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
                {vacancies.length === 0 && (
                  <tr><td colSpan={7} className="empty">Вакансий нет</td></tr>
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
