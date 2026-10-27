:- use_module(graph).
:- use_module(heuristic).
:- use_module(library(heaps)).
:- use_module(library(assoc)).
:- use_module(library(apply)).

% A* search (admissible haversine heuristic).
%
% Data structures:
%   Open    - priority heap keyed on f = g + h
%   Closed  - assoc of already expanded nodes
%   Gs      - assoc Node -> best known cost from Start
%   Parents - assoc Node -> predecessor on the best known path
%
% connected/3 is directed (it comes from the OSM drive network), so one-way
% streets are only ever travelled in their legal direction.

astar(Start, Goal, Path, Cost) :-
    heuristic(Start, Goal, H0),
    singleton_heap(Open0, H0, Start),
    empty_assoc(Empty),
    put_assoc(Start, Empty, 0, Gs0),
    astar_loop(Open0, Goal, Empty, Gs0, Empty, Parents, Cost),
    build_path(Goal, Parents, [], Path).

% get_from_heap/4 fails on an empty heap, which means "no path exists".
astar_loop(Open0, Goal, Closed0, Gs0, Ps0, Ps, Cost) :-
    get_from_heap(Open0, _F, Node, Open1),
    (   Node == Goal
    ->  get_assoc(Goal, Gs0, Cost),
        Ps = Ps0
    ;   get_assoc(Node, Closed0, _)
    ->  % stale heap entry for a node that was already expanded
        astar_loop(Open1, Goal, Closed0, Gs0, Ps0, Ps, Cost)
    ;   put_assoc(Node, Closed0, true, Closed1),
        get_assoc(Node, Gs0, G),
        findall(Next-Step, connected(Node, Next, Step), Edges),
        foldl(relax(Node, G, Goal, Closed1), Edges,
              st(Open1, Gs0, Ps0), st(Open2, Gs1, Ps1)),
        astar_loop(Open2, Goal, Closed1, Gs1, Ps1, Ps, Cost)
    ).

% Relax one outgoing edge of Node.
relax(Node, G, Goal, Closed, Next-Step, st(O0, Gs0, Ps0), State) :-
    NewG is G + Step,
    (   get_assoc(Next, Closed, _)
    ->  State = st(O0, Gs0, Ps0)
    ;   get_assoc(Next, Gs0, Old),
        Old =< NewG
    ->  State = st(O0, Gs0, Ps0)
    ;   heuristic(Next, Goal, H),
        F is NewG + H,
        add_to_heap(O0, F, Next, O),
        put_assoc(Next, Gs0, NewG, Gs),
        put_assoc(Next, Ps0, Node, Ps),
        State = st(O, Gs, Ps)
    ).

% Walk the parent links back from the goal to the start.
build_path(Node, Parents, Acc, Path) :-
    (   get_assoc(Node, Parents, Prev)
    ->  build_path(Prev, Parents, [Node|Acc], Path)
    ;   Path = [Node|Acc]
    ).
