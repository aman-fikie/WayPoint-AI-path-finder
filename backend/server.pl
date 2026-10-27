:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(error)).

% astar.pl is a legacy non-module file, so load it into this context.
% The other files declare modules and must be imported with use_module/1;
% consult/1 loads a module but does not import its exported predicates.
:- consult(astar).
:- use_module(nearest).
:- use_module(path_utils).
:- use_module(traffic).

:- set_setting(http:cors, [*]).
:- http_handler('/route', route_handler, []).

% A coordinate farther than this from the graph is not safely routable by
% snapping to a graph node. It is better to explain the limitation than to
% draw a misleading route across the city or countryside.
maximum_snap_distance_km(1.5).

start_server :-
    http_server(http_dispatch, [port(5000)]),
    writeln('WayPoint AI routing API running at http://localhost:5000'),
    thread_get_message(_).

route_handler(Request) :-
    cors_enable(Request, [methods([post, options])]),
    (   memberchk(method(options), Request)
    ->  format('Status: 204 No Content~n~n')
    ;   catch(handle_route_request(Request), Error, handle_route_error(Error))
    ).

handle_route_request(Request) :-
    http_read_json_dict(Request, Data),
    required_coordinate(Data, start_lat, StartLat),
    required_coordinate(Data, start_lon, StartLon),
    required_coordinate(Data, goal_lat, GoalLat),
    required_coordinate(Data, goal_lon, GoalLon),
    validate_coordinates(StartLat, StartLon, start),
    validate_coordinates(GoalLat, GoalLon, destination),
    nearest_node(StartLat, StartLon, StartNode, StartSnapKm),
    nearest_node(GoalLat, GoalLon, GoalNode, GoalSnapKm),
    maximum_snap_distance_km(MaxSnapKm),
    (   StartSnapKm > MaxSnapKm
    ->  format(atom(Message),
               'Your starting point is ~3f km from the supported road network. This graph currently covers Bahir Dar; select a point nearer to a mapped road.',
               [StartSnapKm]),
        reply_json_dict(_{status:error, code:location_outside_graph, message:Message}, [status(422)])
    ;   GoalSnapKm > MaxSnapKm
    ->  format(atom(Message),
               'The destination is ~3f km from the supported road network. Choose a destination nearer to a mapped road in the supported area.',
               [GoalSnapKm]),
        reply_json_dict(_{status:error, code:destination_outside_graph, message:Message}, [status(422)])
    ;   (   astar(StartNode, GoalNode, Path, Cost)
        ->  path_coordinates(Path, Coordinates),
            route_steps(Path, Steps),
            traffic_rule(Rule),
            TotalDistance is Cost + StartSnapKm + GoalSnapKm,
            Reply = json{
                status: success,
                cost_km: TotalDistance,
                road_distance_km: Cost,
                start_snap_km: StartSnapKm,
                goal_snap_km: GoalSnapKm,
                path: Path,
                coordinates: Coordinates,
                steps: Steps,
                traffic_rule: Rule
            },
            reply_json_dict(Reply)
        ;   reply_json_dict(_{status:error, code:no_path, message:'No connected driving route was found between these locations.'}, [status(404)])
        )
    ).

required_coordinate(Data, Key, Value) :-
    (   get_dict(Key, Data, Raw), number(Raw)
    ->  Value is float(Raw)
    ;   throw(error(domain_error(valid_coordinate, Key), _))
    ).

validate_coordinates(Lat, Lon, Label) :-
    (   Lat >= -90.0, Lat =< 90.0, Lon >= -180.0, Lon =< 180.0
    ->  true
    ;   throw(error(domain_error(geographic_coordinates, Label), _))
    ).

handle_route_error(Error) :-
    message_to_string(Error, Message),
    print_message(error, Error),
    reply_json_dict(_{status:error, code:invalid_request, message:Message}, [status(400)]).
