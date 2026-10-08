import { useEffect, useRef } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { categoryColor, categorize } from "../lib/aqi";

const DELHI_CENTER = [28.65, 77.19];

export default function MapView({
  mode,
  onMapClick,
  locationResult,
  selectedPoint,
  routeStart,
  routeEnd,
  routes,          // array of route option objects (from /route_options)
  selectedRouteIndex, // which one is currently highlighted/selected
  onSelectRoute,    // callback when a route line is clicked on the map
}) {
  const mapRef = useRef(null);
  const mapInstance = useRef(null);
  const layerGroup = useRef(null);

  useEffect(() => {
    if (mapInstance.current) return;

    const map = L.map(mapRef.current, { zoomControl: true }).setView(DELHI_CENTER, 11);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(map);

    layerGroup.current = L.layerGroup().addTo(map);
    mapInstance.current = map;

    map.on("click", (e) => onMapClick(e.latlng.lat, e.latlng.lng));

    return () => {
      map.remove();
      mapInstance.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapInstance.current;
    if (!map) return;
    const handler = (e) => onMapClick(e.latlng.lat, e.latlng.lng);
    map.on("click", handler);
    return () => map.off("click", handler);
  }, [onMapClick]);

  function marker(lat, lng, color) {
    return L.circleMarker([lat, lng], {
      radius: 8,
      color: "#1C2530",
      weight: 2,
      fillColor: color,
      fillOpacity: 0.92,
    });
  }

  useEffect(() => {
    const map = mapInstance.current;
    const group = layerGroup.current;
    if (!map || !group) return;
    group.clearLayers();

    if (mode === "location") {
      if (selectedPoint) {
        const color = locationResult ? categoryColor(locationResult.interpolated_aqi) : "#2E6E5E";
        const m = marker(selectedPoint.lat, selectedPoint.lng, color);
        if (locationResult) {
          m.bindPopup(`<b>${locationResult.interpolated_aqi} AQI</b><br>${categorize(locationResult.interpolated_aqi)}`);
        }
        m.addTo(group);
      }
    }

    if (mode === "route") {
      if (routeStart) marker(routeStart.lat, routeStart.lng, "#2E6E5E").addTo(group);
      if (routeEnd) marker(routeEnd.lat, routeEnd.lng, "#E0533D").addTo(group);

      if (routes && routes.length > 0) {
        let allBounds = [];

        // Draw non-selected routes first (so the selected one renders on top)
        routes.forEach((route, i) => {
          if (i === selectedRouteIndex) return;
          const lineSource = (route.full_route_geometry?.length
            ? route.full_route_geometry
            : route.route_points
          ).map((p) => [p.lat, p.lon]);

          const line = L.polyline(lineSource, {
            color: "#8A8478",
            weight: 4,
            opacity: 0.45,
            dashArray: "1, 8",
          }).addTo(group);
          line.on("click", (e) => {
            L.DomEvent.stopPropagation(e);
            onSelectRoute(i);
          });
          allBounds = allBounds.concat(lineSource);
        });

        // Draw the selected route last, bold and vivid — same idea as Google Maps
        const selected = routes[selectedRouteIndex];
        if (selected) {
          const lineSource = (selected.full_route_geometry?.length
            ? selected.full_route_geometry
            : selected.route_points
          ).map((p) => [p.lat, p.lon]);

          L.polyline(lineSource, {
            color: selected.recommended ? "#2E6E5E" : "#1C2530",
            weight: 6,
            opacity: 0.85,
          }).addTo(group);

          selected.route_points.forEach((p) => {
            const cat = categorize(p.predicted_aqi);
            L.circleMarker([p.lat, p.lon], {
              radius: 6,
              color: "#1C2530",
              weight: 1,
              fillColor: categoryColor(cat),
              fillOpacity: 0.95,
            })
              .bindPopup(`<b>${p.predicted_aqi} AQI</b><br>${cat}`)
              .addTo(group);
          });

          allBounds = allBounds.concat(lineSource);
        }

        if (allBounds.length > 0) {
          map.fitBounds(L.polyline(allBounds).getBounds(), { padding: [40, 40] });
        }
      }
    }
  }, [mode, selectedPoint, routeStart, routeEnd, locationResult, routes, selectedRouteIndex, onSelectRoute]);

  return <div ref={mapRef} className="map-canvas" />;
}