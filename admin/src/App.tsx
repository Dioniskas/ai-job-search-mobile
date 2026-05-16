import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import Vacancies from './pages/Vacancies';
import Employers from './pages/Employers';
import Reports from './pages/Reports';
import Payments from './pages/Payments';

function isAuth() {
  return !!localStorage.getItem('admin_token');
}

function Guard({ children }: { children: React.ReactNode }) {
  return isAuth() ? <>{children}</> : <Navigate to="/login" replace />;
}

function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="layout">
      <Sidebar />
      <main className="main-content">{children}</main>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Guard><AdminLayout><Dashboard /></AdminLayout></Guard>} />
        <Route path="/users" element={<Guard><AdminLayout><Users /></AdminLayout></Guard>} />
        <Route path="/vacancies" element={<Guard><AdminLayout><Vacancies /></AdminLayout></Guard>} />
        <Route path="/employers" element={<Guard><AdminLayout><Employers /></AdminLayout></Guard>} />
        <Route path="/reports" element={<Guard><AdminLayout><Reports /></AdminLayout></Guard>} />
        <Route path="/payments" element={<Guard><AdminLayout><Payments /></AdminLayout></Guard>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
