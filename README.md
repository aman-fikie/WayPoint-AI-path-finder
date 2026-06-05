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

Tools 

*Backend** | SWI-Prolog, `server.pl` (HTTP + JSON API) 
*Frontend** | HTML5, CSS3, Vanilla JS (no frameworks) 
*Algorithms** | `astar.pl`, `heuristic.pl`, `graph.pl`, `nearest.pl`, `path_utils.pl` 
*Caching** | Prolog dict-based cache (see `/cache` folder) 

---

## 🚀 Installation & Running

### 1️⃣ Clone the repo
```bash
git clone https://github.com/yourusername/WayPoint-AI.git
cd WayPoint-AI
cd backend
swipl server.pl
cd frontend
# using Python 3
python -m http.server 3000

Then Vist >>>http://localhost:3000.
