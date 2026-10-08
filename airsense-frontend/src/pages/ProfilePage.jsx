import { useAppContext } from "../context/AppContext";
import { AGE_GROUPS } from "../lib/aqi";

export default function ProfilePage() {
  const { user, logout, ageGroup, setAgeGroup, healthNote, setHealthNote } = useAppContext();

  return (
    <div className="page-container profile-page">
      <h2>Profile & Settings</h2>
      <p className="page-desc">Personalize your AirSense experience. These settings affect the health advisories you receive.</p>

      {/* Account Info Card matching mobile app */}
      <div className="settings-section profile-user-card">
        <div className="user-card-header">
          <div className="user-avatar-circle">
            {user?.displayName ? user.displayName.charAt(0).toUpperCase() : "U"}
          </div>
          <div className="user-card-info">
            <h3 className="user-card-name">{user?.displayName || "AirSense User"}</h3>
            <div className="user-card-email">{user?.email || "guest@airsense.delhi"}</div>
            <div className="user-card-badge">
              {user?.isGuest ? "Guest Access" : "Verified Account"}
            </div>
          </div>
        </div>
      </div>

      <div className="settings-section">
        <h3>Who is this for?</h3>
        <p className="hint">Select the primary person you're checking AQI for. Different age groups have different sensitivities to air pollution.</p>
        
        <div className="age-group-switch profile-age-switch">
          {AGE_GROUPS.map((g) => (
            <button
              key={g.id}
              className={`age-btn ${ageGroup === g.id ? "active" : ""}`}
              onClick={() => setAgeGroup(g.id)}
            >
              {g.label}
            </button>
          ))}
        </div>
        <div className="current-setting-desc">
          Current setting: <strong>{AGE_GROUPS.find(g => g.id === ageGroup)?.label}</strong>
        </div>
      </div>

      <div className="settings-section">
        <h3>Additional health context (optional)</h3>
        <p className="hint">Have asthma? Recovering from a cold? Add notes here and our advisory engine will take them into account. This data stays on your device.</p>
        
        <textarea
          className="health-note-input profile-health-note"
          placeholder="e.g. asthma, recovering from illness — anything extra worth noting"
          value={healthNote}
          onChange={(e) => setHealthNote(e.target.value)}
          rows={4}
        />
      </div>

      <div className="settings-info-card">
        <h4>How these settings work</h4>
        <p>AirSense provides custom health advisories based on the air quality. By setting your age group and health context, the advice becomes tailored specifically to you. All settings are saved securely on your local device.</p>
      </div>

      {/* Log out button */}
      <div className="profile-logout-wrap">
        <button
          type="button"
          className="profile-logout-btn"
          onClick={logout}
        >
          Sign Out of AirSense
        </button>
      </div>
    </div>
  );
}
