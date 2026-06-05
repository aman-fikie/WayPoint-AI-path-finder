:- module(path_utils, [path_coordinates/2]).
:- use_module(graph).

path_coordinates([], []).
path_coordinates([Node|Rest], [json{name: Node, lat: Lat, lon: Lon}|Coords]) :-
    node(Node, Lat, Lon),
    path_coordinates(Rest, Coords).
