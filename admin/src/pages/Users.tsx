import { useEffect, useState, useCallback } from 'react';
import api from '../api';
import Pagination from '../components/Pagination';

interface User {
  id: string;
  email: string;
  role: string;
  isBlocked: boolean;
  createdAt: string;
  seekerProfile?: { firstName: string; lastName: string; city?: string } | null;
  employerProfile?: { companyName: string; isVerified: boolean } | null;
}

const LIMIT = 20;

function roleBadge(role: string) {
  if (role === 'SEEKER')   return <span className="badge badge-blue">Соискатель</span>;
  if (role === 'EMPLOYER') return <span className="badge badge-orange">Работодатель</span>;
  return <span className="badge badge-gray">Админ</span>;
}

export default function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [role, setRole] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), limit: String(LIMIT) });
    if (search) params.set('search', search);
    if (role)   params.set('role', role);
    api.get(`/api/admin/users?${params}`).then((r) => {
      setUsers(r.data.data.users);
      setTotal(r.data.data.total);
      setPages(r.data.data.pages);
    }).finally(() => setLoading(false));
  }, [page, search, role]);

  useEffect(() => { load(); }, [load]);

  function handleSearch(v: string) { setSearch(v); setPage(1); }
  function handleRole(v: string)   { setRole(v);   setPage(1); }

  async function toggleBlock(user: User) {
    const url = `/api/admin/users/${user.id}/${user.isBlocked ? 'unblock' : 'block'}`;
    await api.post(url);
    load();
  }

  function getName(u: User) {
    if (u.seekerProfile) return `${u.seekerProfile.firstName} ${u.seekerProfile.lastName}`;
    if (u.employerProfile) return u.employerProfile.companyName;
    return '—';
  }

  return (
    <div>
      <div className="page-header">
        <h1>Пользователи</h1>
        <p>Управление аккаунтами платформы</p>
      </div>

      <div className="toolbar">
        <input
          className="search-input"
          placeholder="Поиск по email..."
          value={search}
          onChange={(e) => handleSearch(e.target.value)}
        />
        <select className="filter-select" value={role} onChange={(e) => handleRole(e.target.value)}>
          <option value="">Все роли</option>
          <option value="SEEKER">Соискатели</option>
          <option value="EMPLOYER">Работодатели</option>
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
                  <th>Email</th>
                  <th>Имя / Компания</th>
                  <th>Роль</th>
                  <th>Статус</th>
                  <th>Дата</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>{u.email}</td>
                    <td style={{ color: 'var(--text-muted)' }}>{getName(u)}</td>
                    <td>{roleBadge(u.role)}</td>
                    <td>
                      {u.isBlocked
                        ? <span className="badge badge-red">Заблокирован</span>
                        : <span className="badge badge-green">Активен</span>}
                    </td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(u.createdAt).toLocaleDateString('ru')}
                    </td>
                    <td>
                      <div className="btn-actions">
                        <button
                          className={`btn btn-sm ${u.isBlocked ? 'btn-success' : 'btn-danger'}`}
                          onClick={() => toggleBlock(u)}
                        >
                          {u.isBlocked ? 'Разблокировать' : 'Заблокировать'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {users.length === 0 && (
                  <tr><td colSpan={6} className="empty">Пользователи не найдены</td></tr>
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
