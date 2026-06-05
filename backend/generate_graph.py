import osmnx as ox

PLACE = "Bahir Dar, Ethiopia"
OUTPUT_FILE = "graph.pl"


def sanitize_node_id(node_id):
    return f"n{node_id}"


print("Downloading road network from OpenStreetMap...")

# IMPORTANT:
# simplify=False preserves all road geometry points
# so Leaflet can draw realistic road-following paths
G = ox.graph_from_place(
    PLACE,
    network_type="drive",
    simplify=False
)

print("Download complete.")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:

    f.write(":- module(graph, [node/3, edge/3, connected/3]).\n\n")

    # -------------------------
    # WRITE NODES
    # -------------------------
    for node_id, data in G.nodes(data=True):

        lat = data["y"]
        lon = data["x"]

        f.write(
            f"node({sanitize_node_id(node_id)}, "
            f"{lat:.8f}, "
            f"{lon:.8f}).\n"
        )

    f.write("\n")

    # -------------------------
    # WRITE EDGES
    # -------------------------
    for u, v, data in G.edges(data=True):

        length_m = data.get("length", 1.0)
        length_km = length_m / 1000.0

        f.write(
            f"edge({sanitize_node_id(u)}, "
            f"{sanitize_node_id(v)}, "
            f"{length_km:.6f}).\n"
        )

    f.write("\n")

    # -------------------------
    # CONNECTED PREDICATE
    # -------------------------
    f.write(
        "connected(X, Y, Cost) :- edge(X, Y, Cost).\n"
    )

print("graph.pl generated successfully.")