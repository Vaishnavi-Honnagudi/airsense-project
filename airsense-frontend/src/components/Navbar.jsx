import { useState, useEffect } from "react";
import { NavLink } from "react-router-dom";
import AirSenseAiBotModal from "./AirSenseAiBotModal";
import DelhiNotificationsModal from "./DelhiNotificationsModal";

export default function Navbar() {
  const [isAiBotOpen, setIsAiBotOpen] = useState(false);
  const [isNotifOpen, setIsNotifOpen] = useState(false);
  const [toast, setToast] = useState(null);

  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(null), 4500);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  return (
    <>
      <nav className="navbar">
        <div className="navbar-container">
          <div className="brand navbar-brand">
            <div className="brand-mark" />
            <h1>AirSense</h1>
          </div>

          <div className="nav-links">
            <NavLink to="/" className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              <span className="nav-icon">⌂</span>
              Dashboard
            </NavLink>
            <NavLink to="/map" className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              <span className="nav-icon">📍</span>
              Map
            </NavLink>
            <NavLink to="/history" className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              <span className="nav-icon">🕒</span>
              History
            </NavLink>
            <NavLink to="/profile" className={({ isActive }) => `nav-link ${isActive ? "active" : ""}`}>
              <span className="nav-icon">👤</span>
              Profile
            </NavLink>
          </div>

          {/* Quick AI Guide & Notification Triggers matching Mobile App */}
          <div className="nav-extra-actions">
            <button
              type="button"
              className="nav-action-pill ai-pill-btn"
              onClick={() => setIsAiBotOpen(true)}
              title="Open AI Environmental Assistant"
            >
              <span className="pill-icon">🤖</span> Air Guide
            </button>

            <button
              type="button"
              className="nav-action-pill bell-pill-btn"
              onClick={() => setIsNotifOpen(true)}
              title="Delhi Smog & Health Notifications"
            >
              <span className="pill-icon">🔔</span> Alerts
            </button>
          </div>
        </div>
      </nav>

      {/* Toast Notification Banner */}
      {toast && (
        <div className="airsense-toast-banner">
          <div className="toast-content">
            <div className="toast-title">{toast.title}</div>
            <div className="toast-body">{toast.body}</div>
          </div>
          <button className="toast-close-btn" onClick={() => setToast(null)}>✕</button>
        </div>
      )}

      {/* AI Assistant Modal */}
      <AirSenseAiBotModal
        isOpen={isAiBotOpen}
        onClose={() => setIsAiBotOpen(false)}
      />

      {/* Delhi Notifications Settings Modal */}
      <DelhiNotificationsModal
        isOpen={isNotifOpen}
        onClose={() => setIsNotifOpen(false)}
        onShowToast={(t) => setToast(t)}
      />
    </>
  );
}
