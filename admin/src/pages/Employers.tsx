import { useEffect, useState, useCallback } from 'react';
import api from '../api';
import Pagination from '../components/Pagination';

interface Employer {
  id: string;
  companyName: string;
  city?: string;
  website?: string;
  isVerified: boolean;
  user: { email: string; isBlocked: boolean; createdAt: string };
  _count: { vacancies: number };
}

const LIMIT = 20;

export default function Employers() {
  const [employers, setEmployers] = useState<Employer[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), limit: String(LIMIT) });
    if (filter !== '') params.set('verified', filter);
    api.get(`/api/admin/employers?${params}`).then((r) => {
      setEmployers(r.data.data.employers);
      setTotal(r.data.data.total);
      setPages(r.data.data.pages);
    }).finally(() => setLoading(false));
  }, [page, filter]);

  useEffect(() => { load(); }, [load]);

  function handleFilter(v: string) { setFilter(v); setPage(1); }

  async function verify(id: string) {
    await api.post(`/api/admin/employers/${id}/verify`);
    load();
  }

  return (
    <div>
      <div className="page-header">
        <h1>Работодатели</h1>
        <p>Верификация компаний</p>
      </div>

      <div className="toolbar">
        <select className="filter-select" value={filter} onChange={(e) => handleFilter(e.target.value)}>
          <option value="">Все</option>
          <option value="false">Не верифицированы</option>
          <option value="true">Верифицированы</option>
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
                  <th>Компания</th>
                  <th>Email</th>
                  <th>Город</th>
                  <th>Вакансии</th>
                  <th>Верификация</th>
                  <th>Блок</th>
                  <th>Дата</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {employers.map((e) => (
                  <tr key={e.id}>
                    <td style={{ fontWeight: 500 }}>
                      {e.companyName}
                      {e.website && (
                        <a
                          href={e.website}
                          target="_blank"
                          rel="noreferrer"
                          style={{ marginLeft: 6, fontSize: 12, color: 'var(--primary)' }}
                        >
                          ↗
                        </a>
                      )}
                    </td>
                    <td style={{ color: 'var(--text-muted)' }}>{e.user.email}</td>
                    <td style={{ color: 'var(--text-muted)' }}>{e.city ?? '—'}</td>
                    <td style={{ textAlign: 'center' }}>{e._count.vacancies}</td>
                    <td>
                      {e.isVerified
                        ? <span className="badge badge-green">Верифицирован</span>
                        : <span className="badge badge-orange">Ожидает</span>}
                    </td>
                    <td>
                      {e.user.isBlocked
                        ? <span className="badge badge-red">Заблокирован</span>
                        : <span className="badge badge-gray">Активен</span>}
                    </td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(e.user.createdAt).toLocaleDateString('ru')}
                    </td>
                    <td>
                      {!e.isVerified && (
                        <button className="btn btn-sm btn-primary" onClick={() => verify(e.id)}>
                          Верифицировать
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
                {employers.length === 0 && (
                  <tr><td colSpan={8} className="empty">Работодателей нет</td></tr>
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
