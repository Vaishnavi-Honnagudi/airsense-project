import { createContext, useContext, useState, useEffect } from "react";

const AppContext = createContext();

export function AppProvider({ children }) {
  // Auth state persisted in localStorage
  const [user, setUser] = useState(() => {
    try {
      const savedUser = localStorage.getItem("airsense_user");
      return savedUser ? JSON.parse(savedUser) : null;
    } catch {
      return null;
    }
  });

  const [ageGroup, setAgeGroup] = useState(() => {
    return localStorage.getItem("airsense_ageGroup") || "adult";
  });
  
  const [healthNote, setHealthNote] = useState(() => {
    return localStorage.getItem("airsense_healthNote") || "";
  });

  const [history, setHistory] = useState(() => {
    try {
      const saved = localStorage.getItem("airsense_history");
      return saved ? JSON.parse(saved) : [];
    } catch (err) {
      return [];
    }
  });

  useEffect(() => {
    if (user) {
      localStorage.setItem("airsense_user", JSON.stringify(user));
    } else {
      localStorage.removeItem("airsense_user");
    }
  }, [user]);

  useEffect(() => {
    localStorage.setItem("airsense_ageGroup", ageGroup);
  }, [ageGroup]);

  useEffect(() => {
    localStorage.setItem("airsense_healthNote", healthNote);
  }, [healthNote]);

  useEffect(() => {
    localStorage.setItem("airsense_history", JSON.stringify(history));
  }, [history]);

  // Auth actions matching mobile app
  const login = async (email, password) => {
    if (!email || !password) throw new Error("Please enter both email and password.");
    const dummyUser = {
      email,
      isGuest: false,
      displayName: email.split("@")[0],
      createdAt: new Date().toISOString(),
    };
    setUser(dummyUser);
    return dummyUser;
  };

  const signup = async (email, password) => {
    if (!email || !password) throw new Error("Please enter both email and password.");
    if (password.length < 6) throw new Error("Password must be at least 6 characters.");
    const dummyUser = {
      email,
      isGuest: false,
      displayName: email.split("@")[0],
      createdAt: new Date().toISOString(),
    };
    setUser(dummyUser);
    return dummyUser;
  };

  const loginAsGuest = () => {
    const guestUser = {
      email: "guest@airsense.delhi",
      isGuest: true,
      displayName: "Guest User",
      createdAt: new Date().toISOString(),
    };
    setUser(guestUser);
    return guestUser;
  };

  const logout = () => {
    setUser(null);
  };

  const addHistoryEntry = (entry) => {
    setHistory(prev => {
      const newEntry = {
        id: Date.now().toString(),
        timestamp: new Date().toISOString(),
        ...entry
      };
      return [newEntry, ...prev];
    });
  };

  const removeHistoryEntry = (id) => {
    setHistory(prev => prev.filter(entry => entry.id !== id));
  };

  return (
    <AppContext.Provider
      value={{
        user,
        login,
        signup,
        loginAsGuest,
        logout,
        ageGroup, setAgeGroup,
        healthNote, setHealthNote,
        history, addHistoryEntry, removeHistoryEntry
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useAppContext() {
  return useContext(AppContext);
}
