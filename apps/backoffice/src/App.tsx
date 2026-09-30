import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AppLayout } from './components/layout/AppLayout';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { AdminsPage } from './pages/AdminsPage';
import { UsersPage } from './pages/UsersPage';
import { DevicesPage } from './pages/DevicesPage';
import { WallpapersPage } from './pages/WallpapersPage';
import { StickersPage } from './pages/StickersPage';
import { SecurityPage } from './pages/SecurityPage';
import { AnnouncementsPage } from './pages/AnnouncementsPage';
import { AppVersionPage } from './pages/AppVersionPage';
import { ReportsPage } from './pages/ReportsPage';

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route path="/" element={<AppLayout />}>
        <Route index element={<DashboardPage />} />
        <Route path="admins" element={<AdminsPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="devices" element={<DevicesPage />} />
        <Route path="reports" element={<ReportsPage />} />
        <Route path="wallpapers" element={<WallpapersPage />} />
        <Route path="stickers" element={<StickersPage />} />
        <Route path="announcements" element={<AnnouncementsPage />} />
        <Route path="app-version" element={<AppVersionPage />} />
        <Route path="conversations" element={<Navigate to="/" replace />} />
        <Route path="security" element={<SecurityPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
