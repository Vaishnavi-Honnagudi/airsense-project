import React from "react";

export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("AirSense UI Error Boundary caught:", error, errorInfo);
  }

  handleReload = () => {
    this.setState({ hasError: false, error: null });
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "100vh",
          padding: 24,
          fontFamily: "'Inter', sans-serif",
          background: "#F9F6F0",
          color: "#1C2530",
          textAlign: "center"
        }}>
          <div style={{
            background: "#ffffff",
            padding: "36px 32px",
            borderRadius: 16,
            maxWidth: 460,
            boxShadow: "0 10px 30px rgba(0,0,0,0.06)",
            border: "1px solid #E6E1D8"
          }}>
            <div style={{ fontSize: 40, marginBottom: 16 }}>🍃</div>
            <h2 style={{ margin: "0 0 10px", fontSize: 22, fontWeight: 700 }}>AirSense Recovery</h2>
            <p style={{ margin: "0 0 20px", color: "#6B7178", fontSize: 14, lineHeight: 1.5 }}>
              A temporary display error occurred while rendering this view. You can reload to restore your session.
            </p>
            <button
              onClick={this.handleReload}
              style={{
                background: "#2E6E5E",
                color: "#ffffff",
                border: "none",
                borderRadius: 10,
                padding: "12px 24px",
                fontSize: 14,
                fontWeight: 600,
                cursor: "pointer",
                width: "100%"
              }}
            >
              Refresh AirSense
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
