 :- module(nearest, [nearest_node/3]).
:- use_module(graph).
:- use_module(heuristic).

nearest_node(Lat, Lon, Nearest) :-
    findall(
        D-Node,
        (
            node(Node, Lat2, Lon2),
            haversine(Lat, Lon, Lat2, Lon2, D)
        ),
        List
    ),
    keysort(List, [_-Nearest|_]).
