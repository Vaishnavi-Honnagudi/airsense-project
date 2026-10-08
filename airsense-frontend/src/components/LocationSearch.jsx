import { useEffect, useRef, useState } from "react";
import { searchPlace } from "../lib/geocode";

export default function LocationSearch({ placeholder, onSelect, dotColor }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debounceRef = useRef(null);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (query.trim().length < 3) {
      setResults([]);
      return;
    }
    setLoading(true);
    debounceRef.current = setTimeout(async () => {
      try {
        const r = await searchPlace(query);
        setResults(r);
        setOpen(true);
      } catch {
        setResults([]);
      } finally {
        setLoading(false);
      }
    }, 450);
    return () => clearTimeout(debounceRef.current);
  }, [query]);

  function handlePick(place) {
    setQuery(place.name.split(",").slice(0, 2).join(","));
    setOpen(false);
    setResults([]);
    onSelect(place.lat, place.lon, place.name);
  }

  return (
    <div className="search-wrap">
      <div className="search-input-row">
        {dotColor && <span className="dot" style={{ background: dotColor }} />}
        <input
          type="text"
          className="search-input"
          placeholder={placeholder}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => results.length > 0 && setOpen(true)}
        />
        {loading && <span className="search-spinner" />}
      </div>

      {open && results.length > 0 && (
        <div className="search-dropdown">
          {results.map((r, i) => (
            <div key={i} className="search-result" onClick={() => handlePick(r)}>
              {r.name}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
