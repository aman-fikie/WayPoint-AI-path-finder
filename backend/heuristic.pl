:- module(heuristic, [heuristic/3, haversine/5]).
:- use_module(graph).

heuristic(A, B, H) :-
    node(A, Lat1, Lon1),
    node(B, Lat2, Lon2),
    haversine(Lat1, Lon1, Lat2, Lon2, H).

haversine(Lat1, Lon1, Lat2, Lon2, D) :-
    degree_to_rad(Lat1, Lat1R),
    degree_to_rad(Lon1, Lon1R),
    degree_to_rad(Lat2, Lat2R),
    degree_to_rad(Lon2, Lon2R),
    DLat is Lat2R - Lat1R,
    DLon is Lon2R - Lon1R,
    A is sin(DLat/2)**2 +
         cos(Lat1R) * cos(Lat2R) * sin(DLon/2)**2,
    C is 2 * atan2(sqrt(A), sqrt(1-A)),
    D is 6371 * C.

degree_to_rad(Deg, Rad) :-
    Rad is Deg * pi / 180.
