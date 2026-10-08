// Free geocoding via OpenStreetMap's Nominatim - no API key needed.
// Scoped to a Delhi bounding box so results stay relevant.

const DELHI_VIEWBOX = "76.80,28.90,77.40,28.35"; // left,top,right,bottom

export async function searchPlace(query) {
  if (!query || query.trim().length < 3) return [];

  const url = `https://nominatim.openstreetmap.org/search?` +
    `q=${encodeURIComponent(query + ", Delhi")}` +
    `&format=json&limit=5&viewbox=${DELHI_VIEWBOX}&bounded=1`;

  const res = await fetch(url);
  if (!res.ok) throw new Error("Geocoding search failed");
  const data = await res.json();

  return data.map((item) => ({
    name: item.display_name,
    lat: parseFloat(item.lat),
    lon: parseFloat(item.lon),
  }));
}
