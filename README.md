# 🧭 WayPoint AI – Bahir Dar Pathfinder

*AI-powered optimal pathfinding between city nodes using A* algorithm (Prolog backend + web frontend)*

WayPoint AI finds the **clearest and most efficient route** across Bahir Dar city. It models real locations as graph nodes, then applies A* search with custom heuristics to deliver the optimal path – fast.

---

## ✨ Features

- 🎯 **Optimal routing** – shortest distance / least cost path  
- 🧠 **A* search algorithm** implemented in Prolog  
- 🗺️ **Bahir Dar city graph** (nodes = landmarks, edges = roads)  
- ⚡ **Caching** – speeds up repeated queries  
- 🌐 **Web interface** – HTML/CSS/JS for easy interaction  

---

## 🛠️ Technologies

- **Backend** | SWI-Prolog, `server.pl` (HTTP + JSON API)
- **Frontend** | HTML5, CSS3, Vanilla JS (no frameworks)
- **Algorithms** | `astar.pl`, `heuristic.pl`, `graph.pl`, `nearest.pl`, `path_utils.pl`
- **Caching** | Prolog dict-based cache (see `/cache` folder)

---

## 🚀 Installation & Running

### 1️⃣ Clone the repo

```bash
git clone https://github.com/yourusername/WayPoint-AI.git
cd WayPoint-AI
```

### 2️⃣ Start the routing server

In a terminal:

```bash
cd backend
swipl -q -s server.pl -g start_server
```

### 3️⃣ Start the frontend

In a second terminal, from the project root:

```bash
cd frontend
python -m http.server 3000
```

Then visit <http://localhost:3000>.

## Location and route behaviour

- Browser location access requires HTTPS or `localhost`; the browser will ask permission.
- The included road graph is for Bahir Dar, Ethiopia. It cannot provide a valid route for arbitrary locations elsewhere unless the graph is regenerated for that area.
- The Prolog API rejects start/destination points more than 1.5 km from the supported graph instead of silently snapping them to an unrelated road node.
- Route distance includes the graph path and the two short endpoint-to-road snap distances. Estimated time is a rough estimate, not live traffic.
- The map uses the ordered graph coordinates for the route. Short straight connectors between the pins and nearest graph nodes are approximate; they are not verified access paths or lane geometry.
- The graph generator uses directed OSM drive edges, which can represent one-way roads. Traffic restrictions are only as complete as the downloaded OpenStreetMap data.

### Regenerate the Bahir Dar road graph (optional)

Use a Python environment with a compatible OSMnx installation, then run from `backend`:

```bash
python -m pip install osmnx
python generate_graph.py
```

Review the generated graph before replacing the included data. This operation needs internet access and depends on OpenStreetMap/Overpass availability.

## Troubleshooting connection errors

If the browser says it cannot reach the Prolog routing API:

1. Open a terminal and change into the `backend` directory.
2. Run `swipl -q -s server.pl -g start_server`. Keep that terminal open.
3. Confirm the terminal prints `WayPoint AI routing API running at http://localhost:5000`.
4. Open `http://localhost:5000/route` in a browser. A GET request may return a method-related response; that is acceptable as a basic reachability check.
5. If the server reports `Address already in use`, another process is using port 5000; stop that process or configure the frontend and backend to use the same alternate port.

If destination search fails instead, check internet access and browser DevTools → Network. Destination search uses the public OpenStreetMap Nominatim service and is subject to its availability and usage policy. The frontend now reports geocoding and routing connection failures separately.
