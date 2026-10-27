:- module(nearest, [nearest_node/3, nearest_node/4]).
:- use_module(graph).
:- use_module(heuristic).

% Return the nearest graph node and its straight-line distance in kilometres.
% The caller must enforce a maximum snap distance before routing.
nearest_node(Lat, Lon, Nearest) :-
    nearest_node(Lat, Lon, Nearest, _DistanceKm).

nearest_node(Lat, Lon, Nearest, DistanceKm) :-
    findall(
        D-Node,
        (
            node(Node, Lat2, Lon2),
            haversine(Lat, Lon, Lat2, Lon2, D)
        ),
        Distances
    ),
    Distances \= [],
    keysort(Distances, [DistanceKm-Nearest|_]).
