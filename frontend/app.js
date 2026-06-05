const map = L.map('map').setView([11.5936, 37.3908], 13);

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '&copy; OpenStreetMap contributors'
}).addTo(map);

let userLocation = null;
let userMarker = null;
let goalMarker = null;
let routeLine = null;

const locateBtn = document.getElementById('locateBtn');
const searchBtn = document.getElementById('searchBtn');
const searchInput = document.getElementById('searchInput');
const info = document.getElementById('info');

locateBtn.addEventListener('click', () => {

  navigator.geolocation.getCurrentPosition(

    (position) => {

      const lat = position.coords.latitude;
      const lon = position.coords.longitude;

      userLocation = { lat, lon };

      if (userMarker) {
        map.removeLayer(userMarker);
      }

      userMarker = L.marker([lat, lon])
        .addTo(map)
        .bindPopup('Your Location')
        .openPopup();

      map.setView([lat, lon], 15);

    },

    (err) => {
      alert('Unable to get location: ' + err.message);
    },

    {
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 0
    }

  );

});

searchBtn.addEventListener('click', async () => {

  if (!userLocation) {
    alert('Please get your location first.');
    return;
  }

  const placeName = searchInput.value.trim();

  if (!placeName) {
    alert('Enter a place name.');
    return;
  }

  try {

    const geoResponse = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(placeName + ', Bahir Dar, Ethiopia')}`
    );

    const geoData = await geoResponse.json();

    if (geoData.length === 0) {
      alert('Place not found.');
      return;
    }

    const place = geoData[0];

    const goalLat = parseFloat(place.lat);
    const goalLon = parseFloat(place.lon);

    console.log(goalLat, goalLon);

    if (goalMarker) {
      map.removeLayer(goalMarker);
    }

    goalMarker = L.marker([goalLat, goalLon])
      .addTo(map)
      .bindPopup(place.display_name)
      .openPopup();

    const response = await fetch('http://localhost:5000/route', {

      method: 'POST',

      headers: {
        'Content-Type': 'application/json'
      },

      body: JSON.stringify({
        start_lat: userLocation.lat,
        start_lon: userLocation.lon,
        goal_lat: goalLat,
        goal_lon: goalLon
      })

    });

    const data = await response.json();

    console.log(data);

    if (data.status !== 'success') {
      alert(data.message || 'No route found.');
      return;
    }

    let latlngs = data.coordinates.map(p => [
      p.lat,
      p.lon
    ]);

    latlngs.push([goalLat, goalLon]);

    if (routeLine) {
      map.removeLayer(routeLine);
    }

    routeLine = L.polyline(latlngs, {

      color: '#C45B35',
      weight: 6,
      opacity: 0.8,
      smoothFactor: 1

    }).addTo(map);

    map.fitBounds(routeLine.getBounds());

    info.innerHTML = `
      <b>Destination:</b><br>
      ${place.display_name}<br><br>

      <b>Distance:</b>
      ${data.cost_km.toFixed(2)} km
    `;

  }

  catch (err) {

    console.error(err);

    alert('Error searching place.');

  }

});