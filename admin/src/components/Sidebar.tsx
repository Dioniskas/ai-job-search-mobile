import { NavLink, useNavigate } from 'react-router-dom';

const links = [
  { to: '/',           icon: '📊', label: 'Дашборд' },
  { to: '/users',      icon: '👥', label: 'Пользователи' },
  { to: '/vacancies',  icon: '💼', label: 'Вакансии' },
  { to: '/employers',  icon: '🏢', label: 'Работодатели' },
  { to: '/reports',    icon: '🚨', label: 'Жалобы' },
  { to: '/payments',   icon: '💳', label: 'Платежи' },
];

export default function Sidebar() {
  const navigate = useNavigate();

  function logout() {
    localStorage.removeItem('admin_token');
    navigate('/login');
  }

  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <h2>AI Job Search</h2>
        <span>Административная панель</span>
      </div>

      <nav className="sidebar-nav">
        {links.map(({ to, icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) => isActive ? 'active' : ''}
          >
            <span className="nav-icon">{icon}</span>
            {label}
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button onClick={logout}>Выйти</button>
      </div>
    </aside>
  );
}
