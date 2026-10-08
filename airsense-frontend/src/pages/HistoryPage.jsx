import { useAppContext } from "../context/AppContext";

function formatRelativeTime(dateString) {
  const date = new Date(dateString);
  const now = new Date();
  const diffInSeconds = Math.floor((now - date) / 1000);
  
  if (diffInSeconds < 60) return `${diffInSeconds}s ago`;
  const diffInMinutes = Math.floor(diffInSeconds / 60);
  if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
  const diffInHours = Math.floor(diffInMinutes / 60);
  if (diffInHours < 24) return `${diffInHours}h ago`;
  const diffInDays = Math.floor(diffInHours / 24);
  return `${diffInDays}d ago`;
}

function getAqiColor(aqi) {
  if (aqi <= 50) return "#2E6E5E";
  if (aqi <= 100) return "#8CB369";
  if (aqi <= 200) return "#F4D35E";
  if (aqi <= 300) return "#F08A5D";
  if (aqi <= 400) return "#B83B5E";
  return "#6A2C70";
}

export default function HistoryPage() {
  const { history, removeHistoryEntry } = useAppContext();

  return (
    <div className="page-container history-page">
      <h2>Your History</h2>
      <p className="page-desc">Past AQI checks and route searches.</p>

      {history.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">🕒</span>
          <p>No checks yet. Every AQI lookup and route search you make will show up here.</p>
        </div>
      ) : (
        <div className="history-list">
          {history.map(entry => (
            <div key={entry.id} className="history-item">
              <div className="history-item-icon">
                {entry.type === 'location' ? '📍' : '🛣️'}
              </div>
              <div className="history-item-details">
                <div className="history-item-label">{entry.locationLabel}</div>
                <div className="history-item-time">{formatRelativeTime(entry.timestamp)}</div>
              </div>
              <div className="history-item-aqi" style={{ backgroundColor: getAqiColor(entry.aqi) }}>
                {Math.round(entry.aqi)}
              </div>
              <button 
                className="history-item-delete"
                onClick={() => removeHistoryEntry(entry.id)}
                title="Delete"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
