import { useEffect, useState, useCallback } from 'react';
import api from '../api';
import Pagination from '../components/Pagination';

interface Report {
  id: string;
  targetId: string;
  targetType: string;
  reason: string;
  isResolved: boolean;
  resolvedAt?: string;
  createdAt: string;
  reporter: { email: string };
}

const LIMIT = 20;

export default function Reports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState('false');
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), limit: String(LIMIT) });
    if (filter !== '') params.set('resolved', filter);
    api.get(`/api/admin/reports?${params}`).then((r) => {
      setReports(r.data.data.reports);
      setTotal(r.data.data.total);
      setPages(r.data.data.pages);
    }).finally(() => setLoading(false));
  }, [page, filter]);

  useEffect(() => { load(); }, [load]);

  function handleFilter(v: string) { setFilter(v); setPage(1); }

  async function resolve(id: string) {
    await api.post(`/api/admin/reports/${id}/resolve`);
    load();
  }

  function targetLabel(type: string) {
    if (type === 'USER')    return <span className="badge badge-blue">Пользователь</span>;
    if (type === 'VACANCY') return <span className="badge badge-orange">Вакансия</span>;
    return <span className="badge badge-gray">{type}</span>;
  }

  return (
    <div>
      <div className="page-header">
        <h1>Жалобы</h1>
        <p>Рассмотрение обращений пользователей</p>
      </div>

      <div className="toolbar">
        <select className="filter-select" value={filter} onChange={(e) => handleFilter(e.target.value)}>
          <option value="false">Открытые</option>
          <option value="true">Рассмотренные</option>
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
                  <th>От кого</th>
                  <th>Тип</th>
                  <th>Причина</th>
                  <th>Статус</th>
                  <th>Дата</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((r) => (
                  <tr key={r.id}>
                    <td style={{ color: 'var(--text-muted)' }}>{r.reporter.email}</td>
                    <td>{targetLabel(r.targetType)}</td>
                    <td style={{ maxWidth: 300 }}>
                      <span title={r.reason} style={{
                        display: 'block',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                        maxWidth: 280,
                      }}>
                        {r.reason}
                      </span>
                    </td>
                    <td>
                      {r.isResolved
                        ? <span className="badge badge-green">Закрыта</span>
                        : <span className="badge badge-red">Открыта</span>}
                    </td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(r.createdAt).toLocaleDateString('ru')}
                    </td>
                    <td>
                      {!r.isResolved && (
                        <button className="btn btn-sm btn-primary" onClick={() => resolve(r.id)}>
                          Закрыть
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
                {reports.length === 0 && (
                  <tr><td colSpan={6} className="empty">Жалоб нет</td></tr>
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
