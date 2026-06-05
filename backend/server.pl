:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).

:- consult(astar).
:- consult(nearest).
:- consult(path_utils).

:- set_setting(http:cors, [*]).
:- http_handler('/route', route_handler, []).

start_server :-
    http_server(http_dispatch, [port(5000)]),
    writeln('Server running on http://localhost:5000').

route_handler(Request) :-
    cors_enable(Request, [methods([post, options])]),
    (
        member(method(options), Request)
    ->
        format('Status: 204 No Content~n~n')
    ;
        http_read_json_dict(Request, Data),

        get_dict(start_lat, Data, StartLat),
        get_dict(start_lon, Data, StartLon),
        get_dict(goal_lat, Data, GoalLat),
        get_dict(goal_lon, Data, GoalLon),

        nearest_node(StartLat, StartLon, StartNode),
        nearest_node(GoalLat, GoalLon, GoalNode),

        (
            astar(StartNode, GoalNode, Path, Cost)
        ->
            path_coordinates(Path, Coordinates),
            Reply = json{
                status: success,
                cost_km: Cost,
                path: Path,
                coordinates: Coordinates
            }
        ;
            Reply = json{
                status: error,
                message: 'No path found'
            }
        ),

        reply_json_dict(Reply)
    ).
