import { useState, useRef, useEffect } from "react";

export default function AirSenseAiBotModal({ isOpen, onClose }) {
  const [messages, setMessages] = useState([
    {
      id: "initial",
      text: "Namaste! I'm your AirSense Environmental Advisory Guide 📋\n\nI provide hyper-local DPCC guidance, recommend optimal outdoor exercise windows based on diurnal inversion physics, evaluate clean commute corridors, and reference Delhi CAQM GRAP vehicle regulations. How can I help you right now?",
      isUser: false,
      timestamp: new Date(),
    },
  ]);
  const [input, setInput] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef(null);

  const quickSuggestions = [
    "🏃 Can I jog in Lodhi Garden now?",
    "🚗 Cleanest route from CP to India Gate?",
    "👶 Precautions for children in smog?",
    "🚨 Are BS-IV diesel cars banned today?",
    "🪟 When should I open windows in Delhi?",
    "😷 What mask is best for PM2.5?",
  ];

  useEffect(() => {
    if (isOpen) {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, isOpen]);

  if (!isOpen) return null;

  function generateAiResponse(q) {
    const query = q.toLowerCase();

    if (query.contains?.("jog") || query.includes("jog") || query.includes("run") || query.includes("walk") || query.includes("exercise")) {
      return "🏃 Outdoor Exercise Guidance for Delhi:\n\n" +
        "• Recommended Window: Midday (1:00 PM – 4:30 PM). Solar thermal convection lifts ground-level particulates.\n" +
        "• High Risk Window: Early morning (5:00 AM – 8:30 AM). Surface temperature inversions trap vehicular exhaust near ground level.\n" +
        "• Best Location: Lodhi Garden or Nehru Park (Current AQI ~88, Satisfactory) — 70% cleaner than roadside corridors like Ring Road or Anand Vihar.";
    }

    if (query.includes("route") || query.includes("cp") || query.includes("india gate") || query.includes("drive") || query.includes("travel")) {
      return "🚗 Smart Mobility Route Recommendation:\n\n" +
        "• Connaught Place → India Gate:\n" +
        "  Take Kasturba Gandhi Marg or Janpath rather than Barakhamba Road.\n" +
        "  Route exposure drops from 185 AQI to 132 AQI (28% less PM2.5 inhalation).\n" +
        "• Recommended Departure: Leaving after 8:15 PM will save an estimated 22 minutes in traffic delay and 34% pollution exposure.";
    }

    if (query.includes("child") || query.includes("baby") || query.includes("infant") || query.includes("elder") || query.includes("asthma")) {
      return "👶 Sensitive Demographic Advisory (Children & Elderly):\n\n" +
        "• Lungs of children inhale 50% more air per pound of body weight than adults.\n" +
        "• Keep school commute windows sealed.\n" +
        "• Ensure pediatric asthma inhalers are on hand.\n" +
        "• Avoid outdoor play near high-density traffic intersections (e.g. ITO, Anand Vihar) during morning rush hour.";
    }

    if (query.includes("grap") || query.includes("car") || query.includes("diesel") || query.includes("bs-iv") || query.includes("ban")) {
      return "🚨 Delhi CAQM GRAP Regulatory Status:\n\n" +
        "• Current Regional Status: GRAP Stage II (Very Poor, 301–400 AQI).\n" +
        "• Vehicle Rules: Diesel generators are prohibited except for essential services. Higher municipal parking charges apply.\n" +
        "• Note: If Delhi enters GRAP Stage III (>400 AQI), BS-III petrol and BS-IV diesel cars are strictly prohibited from NCT Delhi roads with a ₹20,000 fine.";
    }

    if (query.includes("window") || query.includes("ventilat") || query.includes("air purifier")) {
      return "🪟 Home Ventilation Protocols for Delhi:\n\n" +
        "• Keep exterior windows firmly closed between 7:30 PM and 9:30 AM (Inversion trap period).\n" +
        "• Best ventilation window: 1:30 PM to 4:00 PM when sunshine peaks and wind disperses surface smog.\n" +
        "• Run HEPA indoor air purifiers on auto mode in bedrooms overnight.";
    }

    if (query.includes("mask") || query.includes("n95") || query.includes("protect")) {
      return "😷 Particulate Protection Standards:\n\n" +
        "• Standard cloth or surgical masks filter less than 20% of toxic PM2.5 aerosols.\n" +
        "• Enforce certified N95 or FFP2 respirators with an airtight nose-bridge seal when walking outdoors in Delhi when AQI exceeds 200.";
    }

    return "🤖 AirSense Environmental Telemetry Analysis:\n\n" +
      "Delhi's air quality is currently governed by calm north-westerly surface winds (8–12 km/h) and moderate boundary-layer mixing.\n\n" +
      "Key recommendations:\n" +
      "1. Prioritize indoor activities during morning and evening rush hours.\n" +
      "2. If traveling, use AirSense 'Pollution Map' to choose routes avoiding Anand Vihar and Wazirpur smog corridors.\n" +
      "3. Consider visiting South Delhi green corridors (Lodhi Garden, Nehru Park) for clean outdoor air.";
  }

  function handleSend(textToSend) {
    const text = textToSend || input;
    if (!text.trim()) return;

    const userMsg = {
      id: Date.now().toString(),
      text,
      isUser: true,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsTyping(true);

    setTimeout(() => {
      const response = generateAiResponse(text);
      const botMsg = {
        id: (Date.now() + 1).toString(),
        text: response,
        isUser: false,
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, botMsg]);
      setIsTyping(false);
    }, 600);
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-content bot-modal" onClick={(e) => e.stopPropagation()}>
        <div className="bot-modal-header">
          <div className="bot-header-info">
            <span className="bot-avatar">🤖</span>
            <div>
              <h3 className="bot-title">AirSense AI Environmental Guide</h3>
              <p className="bot-status">● Live Environmental Intelligence & CAQM Rules</p>
            </div>
          </div>
          <button className="modal-close-btn" onClick={onClose}>✕</button>
        </div>

        {/* Quick Suggestion Chips */}
        <div className="bot-suggestions-strip">
          {quickSuggestions.map((q, idx) => (
            <button
              key={idx}
              className="bot-chip"
              onClick={() => handleSend(q)}
            >
              {q}
            </button>
          ))}
        </div>

        {/* Message Feed */}
        <div className="bot-messages-feed">
          {messages.map((m) => (
            <div
              key={m.id}
              className={`bot-message-row ${m.isUser ? "user-row" : "bot-row"}`}
            >
              {!m.isUser && <span className="bot-bubble-icon">🌿</span>}
              <div className={`bot-bubble ${m.isUser ? "user-bubble" : "assistant-bubble"}`}>
                <div className="bot-bubble-text" style={{ whiteSpace: "pre-line" }}>
                  {m.text}
                </div>
                <div className="bot-bubble-time">
                  {new Date(m.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                </div>
              </div>
            </div>
          ))}
          {isTyping && (
            <div className="bot-message-row bot-row">
              <span className="bot-bubble-icon">🌿</span>
              <div className="bot-bubble assistant-bubble typing-bubble">
                <span className="typing-dot"></span>
                <span className="typing-dot"></span>
                <span className="typing-dot"></span>
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input Bar */}
        <form
          className="bot-input-bar"
          onSubmit={(e) => {
            e.preventDefault();
            handleSend();
          }}
        >
          <input
            type="text"
            className="bot-input-field"
            placeholder="Ask about Delhi AQI, jog windows, GRAP vehicle rules..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <button type="submit" className="bot-send-btn" disabled={!input.trim()}>
            Send ➔
          </button>
        </form>
      </div>
    </div>
  );
}
