import { useState, useEffect } from "react";

export default function DelhiNotificationsModal({ isOpen, onClose, onShowToast }) {
  const [prefs, setPrefs] = useState(() => {
    try {
      const saved = localStorage.getItem("airsense_notif_prefs");
      return saved
        ? JSON.parse(saved)
        : {
            morning: true,
            inversion: true,
            grap: true,
            severe: false,
          };
    } catch {
      return { morning: true, inversion: true, grap: true, severe: false };
    }
  });

  useEffect(() => {
    localStorage.setItem("airsense_notif_prefs", JSON.stringify(prefs));
  }, [prefs]);

  if (!isOpen) return null;

  function toggle(key) {
    setPrefs((prev) => ({ ...prev, [key]: !prev[key] }));
  }

  function handleTestAlert() {
    onClose();
    if (onShowToast) {
      onShowToast({
        title: "🚨 Delhi Smog Inversion Alert",
        body: "Evening boundary layer falling below 400m. Inhaled PM2.5 concentrations rising along Ring Road & Anand Vihar. Reschedule outdoor runs.",
      });
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-content notif-modal" onClick={(e) => e.stopPropagation()}>
        <div className="notif-modal-header">
          <div className="notif-header-title">
            <span className="notif-bell-icon">🔔</span>
            <div>
              <h3>Delhi Air Quality Alerts</h3>
              <p>Configure automated health notices & smog inversion briefings</p>
            </div>
          </div>
          <button className="modal-close-btn" onClick={onClose}>✕</button>
        </div>

        <div className="notif-options-list">
          <div className="notif-option-card">
            <div className="notif-text">
              <div className="notif-name">🌅 Morning Jog & Commute Briefing</div>
              <div className="notif-desc">Receive a 7:00 AM forecast of diurnal clean-air windows before stepping outdoors.</div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={prefs.morning}
                onChange={() => toggle("morning")}
              />
              <span className="slider round"></span>
            </label>
          </div>

          <div className="notif-option-card">
            <div className="notif-text">
              <div className="notif-name">🌫️ Evening Smog Inversion Alert</div>
              <div className="notif-desc">Automatic trigger when nocturnal atmospheric inversions begin trapping exhaust (6:30 PM).</div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={prefs.inversion}
                onChange={() => toggle("inversion")}
              />
              <span className="slider round"></span>
            </label>
          </div>

          <div className="notif-option-card">
            <div className="notif-text">
              <div className="notif-name">🚨 CAQM GRAP Vehicle Restrictions</div>
              <div className="notif-desc">Immediate alerts when Stage III or Stage IV restrictions prohibit BS-III petrol or BS-IV diesel vehicles.</div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={prefs.grap}
                onChange={() => toggle("grap")}
              />
              <span className="slider round"></span>
            </label>
          </div>

          <div className="notif-option-card">
            <div className="notif-text">
              <div className="notif-name">⚠️ Severe Exposure Threshold (&gt;300 AQI)</div>
              <div className="notif-desc">Emergency push notification if your saved neighborhood crosses into Very Poor or Severe.</div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={prefs.severe}
                onChange={() => toggle("severe")}
              />
              <span className="slider round"></span>
            </label>
          </div>
        </div>

        <div className="notif-modal-actions">
          <button className="test-alert-btn" onClick={handleTestAlert}>
            🔔 Send Test Notification
          </button>
        </div>
      </div>
    </div>
  );
}
