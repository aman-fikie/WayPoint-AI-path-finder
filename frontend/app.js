// WayPoint AI — browser UI for the Prolog A* driving router.
// The displayed road route uses the actual ordered coordinates returned by graph.pl.

const DEFAULT_CENTER = [11.5936, 37.3908];
const ROUTE_API_URL = `${window.location.protocol === 'file:' ? 'http:' : window.location.protocol}//${window.location.hostname || 'localhost'}:5000/route`;
const MAX_GEOLOCATION_AGE_MS = 5000;

const map = L.map('map').setView(DEFAULT_CENTER, 13);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '&copy; OpenStreetMap contributors',
  maxZoom: 19
}).addTo(map);

let userLocation = null;
let userMarker = null;
let userAccuracyCircle = null;
let goalMarker = null;
let routeLine = null;
let isLocating = false;
let isRouting = false;

const el = id => document.getElementById(id);
const locateBtn = el('locateBtn');
const searchBtn = el('searchBtn');
const searchInput = el('searchInput');
const info = el('info');
const coordRow = el('coordRow');
const coordLat = el('coordLat');
const coordLon = el('coordLon');
const badgeDot = el('badgeDot');
const badgeText = el('badgeText');
const progressBar = el('progressBar');
const resultSection = el('resultSection');
const stepOrigin = el('stepOrigin');
const stepDest = el('stepDest');

const userIcon = L.divIcon({
  className: 'user-marker',
  html: '<div class="user-marker-pulse"></div><div class="user-marker-dot"></div>',
  iconSize: [20, 20], iconAnchor: [10, 10]
});
const goalIcon = L.divIcon({
  className: 'goal-marker',
  html: '<div class="goal-marker-pin"></div>',
  iconSize: [24, 30], iconAnchor: [12, 28]
});

function setBadge(state, text) {
  badgeDot.className = `badge-dot${state ? ` ${state}` : ''}`;
  badgeText.textContent = text;
}
function showProgress(show) { progressBar.classList.toggle('active', show); }
function showResultSection() { resultSection.classList.add('result-visible'); }
function clearRoute() {
  if (routeLine) map.removeLayer(routeLine);
  routeLine = null;
}
function showErrorInInfo(message) {
  showResultSection();
  info.replaceChildren();
  const error = document.createElement('div');
  error.className = 'result-error';
  error.textContent = message;
  info.appendChild(error);
}
function showLoadingInInfo(message) {
  showResultSection();
  info.innerHTML = '<div class="result-loading"><div class="spinner"></div><p></p></div>';
  info.querySelector('p').textContent = message;
}
function updateLocationCoordinates(lat, lon) {
  coordLat.textContent = lat.toFixed(6);
  coordLon.textContent = lon.toFixed(6);
  coordRow.classList.add('visible');
  stepOrigin.classList.add('step-done');
}
function formatDistance(km) {
  if (!Number.isFinite(km)) return '—';
  return km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(2)} km`;
}
function formatTime(km) {
  // This is a rough estimate, not live traffic or a guaranteed ETA.
  const minutes = Math.max(1, Math.round((km / 25) * 60));
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder ? `${hours} hr ${remainder} min` : `${hours} hr`;
}
function validCoordinates(lat, lon) {
  return Number.isFinite(lat) && Number.isFinite(lon)
    && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}
function setUserLocation(lat, lon, label, accuracy = null, shouldCenter = true) {
  userLocation = { lat, lon };
  updateLocationCoordinates(lat, lon);
  if (userMarker) map.removeLayer(userMarker);
  if (userAccuracyCircle) map.removeLayer(userAccuracyCircle);

  userMarker = L.marker([lat, lon], { draggable: true, icon: userIcon })
    .addTo(map).bindPopup(`${label} — drag the pin to adjust`);
  if (Number.isFinite(accuracy) && accuracy > 0) {
    userAccuracyCircle = L.circle([lat, lon], {
      radius: accuracy, color: '#4A7B5F', fillColor: '#4A7B5F',
      fillOpacity: 0.08, weight: 1, dashArray: '4 4'
    }).addTo(map);
  }
  userMarker.on('dragend', event => {
    const p = event.target.getLatLng();
    userLocation = { lat: p.lat, lon: p.lng };
    updateLocationCoordinates(p.lat, p.lng);
    if (userAccuracyCircle) userAccuracyCircle.setLatLng([p.lat, p.lng]);
    clearRoute();
    stepDest.classList.remove('step-done');
    showErrorInInfo('Starting point changed. Select or keep your destination, then click Find Route again.');
    setBadge('', 'Ready');
  });
  if (shouldCenter) map.setView([lat, lon], 16);
}

locateBtn.addEventListener('click', () => {
  if (isLocating) return;
  if (!navigator.geolocation) {
    showErrorInInfo('This browser does not support location detection. Open the app in a modern browser.');
    setBadge('error', 'Unsupported');
    return;
  }
  isLocating = true;
  locateBtn.disabled = true;
  const originalContent = locateBtn.innerHTML;
  locateBtn.innerHTML = '<div class="btn-spinner"></div> Detecting…';
  setBadge('computing', 'Locating…');

  navigator.geolocation.getCurrentPosition(position => {
    isLocating = false;
    locateBtn.disabled = false;
    locateBtn.innerHTML = originalContent;
    const { latitude: lat, longitude: lon, accuracy } = position.coords;
    if (!validCoordinates(lat, lon)) {
      showErrorInInfo('The browser returned invalid coordinates. Please try Locate Me again.');
      setBadge('error', 'Invalid location');
      return;
    }
    setUserLocation(lat, lon, 'Your location', accuracy);
    if (accuracy > 5000) {
      showErrorInInfo(`Location found, but the reported accuracy is low (about ±${Math.round(accuracy)} m). Check device location settings or drag the pin to correct it.`);
      setBadge('found', 'Low accuracy');
    } else {
      showResultSection();
      info.textContent = `Location detected. Accuracy estimate: ±${Math.round(accuracy)} m. Enter a destination to calculate a route.`;
      setBadge('found', 'Location found');
    }
  }, error => {
    isLocating = false;
    locateBtn.disabled = false;
    locateBtn.innerHTML = originalContent;
    const messages = {
      1: 'Location permission was denied. Allow location access in your browser settings, then try again.',
      2: 'Your location is currently unavailable. Check device location services and try again.',
      3: 'Location detection timed out. Try again in an area with a better location signal.'
    };
    showErrorInInfo(messages[error.code] || `Unable to detect location: ${error.message}`);
    setBadge('error', 'Location error');
  }, { enableHighAccuracy: true, timeout: 30000, maximumAge: MAX_GEOLOCATION_AGE_MS });
});

async function geocodeDestination(query) {
  // Bias results to the road graph's intended operating area without silently
  // choosing an arbitrary result elsewhere in Ethiopia.
  const params = new URLSearchParams({
    format: 'jsonv2', q: `${query}, Bahir Dar, Ethiopia`, countrycodes: 'et',
    limit: '5', addressdetails: '1',
    viewbox: '37.30,11.66,37.48,11.52', bounded: '1'
  });
  let response;
  try {
    response = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, {
      headers: { Accept: 'application/json' }
    });
  } catch (cause) {
    throw new Error('Cannot reach the destination geocoding service. Check your internet connection, then try again.');
  }
  if (!response.ok) throw new Error(`Destination search failed (HTTP ${response.status}). Please try again.`);
  const results = await response.json();
  if (!Array.isArray(results) || results.length === 0) {
    throw new Error(`Could not find “${query}” in the supported Bahir Dar search area. Try a more specific landmark or address.`);
  }
  const place = results[0];
  const lat = Number(place.lat);
  const lon = Number(place.lon);
  if (!validCoordinates(lat, lon)) throw new Error('The destination search returned invalid coordinates. Please try another destination.');
  return { ...place, lat, lon };
}

function appendTextBlock(parent, label, value) {
  const heading = document.createElement('b');
  heading.textContent = label;
  const content = document.createElement('div');
  content.className = 'route-detail-value';
  content.textContent = value;
  parent.append(heading, content);
}
function renderRouteResult(place, data) {
  info.replaceChildren();
  appendTextBlock(info, 'From', `Your location (${userLocation.lat.toFixed(5)}, ${userLocation.lon.toFixed(5)})`);
  appendTextBlock(info, 'Destination', place.display_name);
  appendTextBlock(info, 'Road distance', formatDistance(Number(data.road_distance_km)));
  const total = Number(data.cost_km);
  appendTextBlock(info, 'Approx. travel time', `${formatTime(total)} (estimate; no live traffic data)`);
  appendTextBlock(info, 'Traffic rule', data.traffic_rule || 'Keep to the right side of the road; obey road signs and restrictions.');

  const title = document.createElement('b');
  title.className = 'directions-title';
  title.textContent = 'Driving directions';
  info.appendChild(title);
  const list = document.createElement('ol');
  list.className = 'directions-list';
  const steps = Array.isArray(data.steps) ? data.steps : [];
  steps.forEach(step => {
    const li = document.createElement('li');
    const instruction = document.createElement('span');
    instruction.textContent = step.instruction || 'Continue along the route';
    li.appendChild(instruction);
    if (Number.isFinite(Number(step.distance_m)) && Number(step.distance_m) > 0) {
      const distance = document.createElement('small');
      distance.textContent = formatDistance(Number(step.distance_m) / 1000);
      li.appendChild(distance);
    }
    list.appendChild(li);
  });
  if (!steps.length) {
    const li = document.createElement('li');
    li.textContent = 'Follow the highlighted road route and obey posted signs.';
    list.appendChild(li);
  }
  info.appendChild(list);
}

async function findRoute() {
  if (isRouting) return;
  if (!userLocation) {
    showErrorInInfo('First click Locate Me and allow location access, or set your starting point by dragging the green marker after locating it.');
    setBadge('error', 'No location');
    return;
  }
  const placeName = searchInput.value.trim();
  if (!placeName) {
    showErrorInInfo('Enter a destination name or address first.');
    setBadge('error', 'No destination');
    searchInput.focus();
    return;
  }

  isRouting = true;
  searchBtn.disabled = true;
  const originalContent = searchBtn.innerHTML;
  searchBtn.innerHTML = '<div class="btn-spinner"></div> Finding route…';
  clearRoute();
  showLoadingInInfo('Finding destination and calculating a road route…');
  showProgress(true);
  setBadge('computing', 'Computing route…');
  stepDest.classList.remove('step-done');

  try {
    const place = await geocodeDestination(placeName);
    if (goalMarker) map.removeLayer(goalMarker);
    goalMarker = L.marker([place.lat, place.lon], { icon: goalIcon }).addTo(map);
    goalMarker.bindPopup('Destination').openPopup();

    let response;
    try {
      response = await fetch(ROUTE_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          start_lat: userLocation.lat, start_lon: userLocation.lon,
          goal_lat: place.lat, goal_lon: place.lon
        })
      });
    } catch (cause) {
      throw new Error(`Cannot reach the Prolog routing API at ${ROUTE_API_URL}. Start the backend from the backend folder and confirm that port 5000 is available.`);
    }
    let data;
    try { data = await response.json(); }
    catch { throw new Error(`The routing server returned an unreadable response (HTTP ${response.status}). Check the Prolog backend logs.`); }
    if (!response.ok || data?.status !== 'success') {
      throw new Error(data?.message || `No route found (HTTP ${response.status}).`);
    }
    if (!Array.isArray(data.coordinates) || data.coordinates.length === 0) {
      throw new Error('The routing server returned no road coordinates, so the route cannot be displayed.');
    }

    const roadLatLngs = data.coordinates
      .filter(p => validCoordinates(Number(p.lat), Number(p.lon)))
      .map(p => [Number(p.lat), Number(p.lon)]);
    if (!roadLatLngs.length) throw new Error('The route contains no valid geographic coordinates.');

    // The first/last short connectors visually join the user/destination pins
    // to the nearest graph nodes. The graph path between them follows road nodes.
    const latlngs = [[userLocation.lat, userLocation.lon], ...roadLatLngs, [place.lat, place.lon]];
    routeLine = L.polyline(latlngs, {
      color: '#C45B35', weight: 6, opacity: 0.9,
      smoothFactor: 0.5, lineCap: 'round', lineJoin: 'round'
    }).addTo(map);
    if (userMarker) userMarker.setZIndexOffset(1000);
    if (goalMarker) goalMarker.setZIndexOffset(1000);
    map.fitBounds(routeLine.getBounds(), { padding: [60, 60], maxZoom: 16 });
    renderRouteResult(place, data);
    stepDest.classList.add('step-done');
    setBadge('found', 'Route found');
  } catch (error) {
    console.error('WayPoint route error:', error);
    const message = error.message || 'An unexpected error occurred while calculating the route.';
    showErrorInInfo(message);
    setBadge('error', 'Route failed');
  } finally {
    isRouting = false;
    searchBtn.disabled = false;
    searchBtn.innerHTML = originalContent;
    showProgress(false);
  }
}

searchBtn.addEventListener('click', findRoute);
searchInput.addEventListener('keydown', event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    findRoute();
  }
});

// Leaflet sometimes needs a size refresh after the page has finished layout.
window.addEventListener('load', () => map.invalidateSize());
