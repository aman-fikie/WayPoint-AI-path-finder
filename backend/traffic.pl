:- module(traffic, [right_lane_coordinates/2, route_steps/2, traffic_rule/1]).
:- use_module(graph).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(library(lists)).

% ============================================================
% Ethiopian traffic rule: vehicles drive on the RIGHT-hand side
% of the road (overtake on the left, roundabouts run
% counter-clockwise, left turns cross oncoming traffic).
% ============================================================

traffic_rule('Ethiopia: drive on the right-hand side of the road').

% Distance (metres) the drawn route is shifted to the right of the
% road centre-line, approximating the driver's lane.
lane_offset_m(6.0).

% Minimum heading change (degrees) between two consecutive road
% segments that is announced as a turn.
turn_threshold_deg(35).

% ------------------------------------------------------------
% Geometry helpers
% ------------------------------------------------------------

path_points([], []).
path_points([Node|Rest], [pt(Lat, Lon)|Pts]) :-
    node(Node, Lat, Lon),
    path_points(Rest, Pts).

% Local flat-earth vector (east DX, north DY, length) in metres.
seg_vec(pt(La1, Lo1), pt(La2, Lo2), vec(DX, DY, Len)) :-
    DY is (La2 - La1) * 110540.0,
    DX is (Lo2 - Lo1) * 111320.0 * cos(La1 * pi / 180),
    Len is sqrt(DX*DX + DY*DY).

% Compass bearing in degrees [0, 360), clockwise from north.
bearing(DX, DY, B) :-
    B0 is atan2(DX, DY) * 180 / pi,
    (   B0 < 0 -> B is B0 + 360 ; B = B0 ).

% Signed heading change in [-180, 180). Positive = turn right (clockwise).
turn_delta(From, To, Delta) :-
    D0 is To - From,
    Delta is D0 - 360 * floor((D0 + 180) / 360).

compass(B, Name) :-
    I is floor((B + 22.5) / 45) mod 8,
    nth0(I, [north, northeast, east, southeast,
             south, southwest, west, northwest], Name).

% ------------------------------------------------------------
% Right-hand lane geometry
% ------------------------------------------------------------

% right_lane_coordinates(+NodePath, -Coords)
% Coords is a list of json{lat, lon} points shifted to the right of the
% direction of travel.
right_lane_coordinates(Path, Coords) :-
    path_points(Path, Pts),
    (   Pts = [_, _|_]
    ->  unit_segments(Pts, Units),
        shift_points(Pts, none, Units, Shifted)
    ;   Shifted = Pts
    ),
    maplist(pt_dict, Shifted, Coords).

pt_dict(pt(Lat, Lon), json{lat: Lat, lon: Lon}).

% Unit direction vector of every segment (u(0,0) for degenerate ones).
unit_segments([], []) :- !.
unit_segments([_], []) :- !.
unit_segments([P, Q|Rest], [U|Us]) :-
    seg_vec(P, Q, vec(DX, DY, Len)),
    (   Len < 1.0e-6
    ->  U = u(0.0, 0.0)
    ;   UX is DX / Len, UY is DY / Len, U = u(UX, UY)
    ),
    unit_segments([Q|Rest], Us).

% Each point uses the incoming and outgoing segment directions.
shift_points([P], In, [], [S]) :-
    !,
    shift_point(P, In, none, S).
shift_points([P|Ps], In, [U|Us], [S|Ss]) :-
    shift_point(P, In, U, S),
    shift_points(Ps, U, Us, Ss).

shift_point(pt(Lat, Lon), In, Out, pt(Lat2, Lon2)) :-
    findall(X-Y, (member(u(X, Y), [In, Out])), Us),
    length(Us, Count),
    sum_vectors(Us, 0.0, 0.0, SumX, SumY),
    N is sqrt(SumX*SumX + SumY*SumY),
    (   Count > 0, N > 1.0e-6
    ->  lane_offset_m(Offset),
        Mean is N / Count,                    % = cos(half turn angle)
        Scale is Offset / max(Mean, 0.5),     % mitre, clamped
        % right-hand normal of direction (x east, y north) is (y, -x)
        NX is SumY / N,
        NY is -SumX / N,
        DLat is Scale * NY / 110540.0,
        DLon is Scale * NX / (111320.0 * cos(Lat * pi / 180)),
        Lat2 is Lat + DLat,
        Lon2 is Lon + DLon
    ;   Lat2 = Lat,
        Lon2 = Lon
    ).

sum_vectors([], SX, SY, SX, SY).
sum_vectors([X-Y|T], SX0, SY0, SX, SY) :-
    SX1 is SX0 + X,
    SY1 is SY0 + Y,
    sum_vectors(T, SX1, SY1, SX, SY).

% ------------------------------------------------------------
% Turn-by-turn steps for right-hand traffic
% ------------------------------------------------------------

% route_steps(+NodePath, -Steps)
route_steps(Path, Steps) :-
    path_points(Path, Pts),
    segments(Pts, Segs),
    (   Segs = [seg(B0, L0, P0)|Rest],
        last(Pts, End)
    ->  compass(B0, Dir),
        format(atom(Text),
               'Head ~w and keep to the right side of the road', [Dir]),
        walk(Rest, B0, L0, step(Text, start, P0), End, Steps)
    ;   Steps = []
    ).

% Collapse the path into segments of non-zero length with a bearing.
segments([P, Q|Rest], Segs) :-
    !,
    seg_vec(P, Q, vec(DX, DY, Len)),
    (   Len < 0.5
    ->  Segs = Segs1
    ;   bearing(DX, DY, B),
        Segs = [seg(B, Len, P)|Segs1]
    ),
    segments([Q|Rest], Segs1).
segments(_, []).

walk([], _, Acc, Cur, pt(Lat, Lon), [Done, Arrive]) :-
    finish_step(Cur, Acc, Done),
    Arrive = json{instruction: 'You have arrived at your destination',
                  type: arrive, distance_m: 0, lat: Lat, lon: Lon}.
walk([seg(B, L, P)|Rest], PrevB, Acc, Cur, End, Steps) :-
    turn_delta(PrevB, B, Delta),
    turn_threshold_deg(Threshold),
    (   abs(Delta) >= Threshold
    ->  classify_turn(Delta, Kind, Text),
        finish_step(Cur, Acc, Done),
        Steps = [Done|Steps1],
        walk(Rest, B, L, step(Text, Kind, P), End, Steps1)
    ;   Acc1 is Acc + L,
        walk(Rest, B, Acc1, Cur, End, Steps)
    ).

finish_step(step(Text, Kind, pt(Lat, Lon)), Dist,
            json{instruction: Text, type: Kind,
                 distance_m: D, lat: Lat, lon: Lon}) :-
    D is round(Dist).

% Positive delta = clockwise = right turn.
classify_turn(Delta, Kind, Text) :-
    A is abs(Delta),
    (   Delta > 0 -> Side = right ; Side = left ),
    (   A >= 170
    ->  Kind = u_turn,
        Text = 'Make a U-turn when it is safe'
    ;   A >= 120
    ->  sharp_text(Side, Kind, Text)
    ;   A >= 60
    ->  turn_text(Side, Kind, Text)
    ;   slight_text(Side, Kind, Text)
    ).

turn_text(right, right, 'Turn right').
turn_text(left,  left,  'Turn left (cross the oncoming lane, give way)').

sharp_text(right, sharp_right, 'Turn sharp right').
sharp_text(left,  sharp_left,  'Turn sharp left (cross the oncoming lane, give way)').

slight_text(right, slight_right, 'Bear right').
slight_text(left,  slight_left,  'Bear left').

