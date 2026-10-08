import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AppProvider, useAppContext } from "./context/AppContext";
import { ErrorBoundary } from "./components/ErrorBoundary";
import Navbar from "./components/Navbar";
import DashboardPage from "./pages/DashboardPage";
import MapPage from "./pages/MapPage";
import HistoryPage from "./pages/HistoryPage";
import ProfilePage from "./pages/ProfilePage";
import LoginPage from "./pages/LoginPage";
import "./styles.css";

function AppContent() {
  const { user } = useAppContext();

  // If not logged in and not guest, show the LoginScreen matching the mobile app
  if (!user) {
    return <LoginPage />;
  }

  return (
    <div className="app-layout">
      <Navbar />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/map" element={<MapPage />} />
          <Route path="/history" element={<HistoryPage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      <BrowserRouter>
        <AppProvider>
          <AppContent />
        </AppProvider>
      </BrowserRouter>
    </ErrorBoundary>
  );
}