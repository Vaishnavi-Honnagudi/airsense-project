import { useState } from "react";
import { useAppContext } from "../context/AppContext";

export default function LoginPage() {
  const { login, signup, loginAsGuest } = useAppContext();
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (isSignUp) {
        await signup(email, password);
      } else {
        await login(email, password);
      }
    } catch (err) {
      setError(err.message || "Authentication failed.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-screen-wrap">
      <div className="login-card">
        {/* Brand header matching mobile app */}
        <div className="login-brand">
          <span className="brand-dot" />
          <h1 className="login-title">AirSense</h1>
        </div>
        <p className="login-subtitle">Sign in to see your saved history</p>

        {error && <div className="login-error-banner">{error}</div>}

        <form onSubmit={handleSubmit} className="login-form">
          <div className="login-field">
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="login-input"
              required
            />
          </div>

          <div className="login-field">
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="login-input"
              required
            />
          </div>

          <button type="submit" className="login-submit-btn" disabled={loading}>
            {loading ? "Processing..." : (isSignUp ? "Create account" : "Sign in")}
          </button>
        </form>

        <div className="login-toggle-row">
          <button
            type="button"
            className="login-toggle-link"
            onClick={() => {
              setIsSignUp(!isSignUp);
              setError("");
            }}
          >
            {isSignUp ? "Already have an account? Sign in" : "New here? Create an account"}
          </button>
        </div>

        <div className="login-divider">
          <span className="divider-line" />
          <span className="divider-text">or</span>
          <span className="divider-line" />
        </div>

        <button
          type="button"
          className="guest-login-btn"
          onClick={loginAsGuest}
        >
          Continue as Guest
        </button>
      </div>
    </div>
  );
}
