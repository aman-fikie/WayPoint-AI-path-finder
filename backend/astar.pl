:- use_module(graph).
:- use_module(heuristic).

astar(Start, Goal, Path, Cost) :-
    heuristic(Start, Goal, H),
    astar_search([[H, 0, Start, [Start]]], Goal, RevPath, Cost),
    reverse(RevPath, Path).

astar_search([[_, Cost, Goal, Path]|_], Goal, Path, Cost).

astar_search([[_, G, Current, Path]|Rest], Goal, FinalPath, FinalCost) :-
    findall(
        [FNext, NewG, Next, [Next|Path]],
        (
            connected(Current, Next, StepCost),
            \+ member(Next, Path),
            NewG is G + StepCost,
            heuristic(Next, Goal, HNext),
            FNext is NewG + HNext
        ),
        Neighbors
    ),
    append(Rest, Neighbors, CombinedQueue),
    sort_queue(CombinedQueue, SortedQueue),
    astar_search(SortedQueue, Goal, FinalPath, FinalCost).

sort_queue(Queue, Sorted) :-
    predsort(compare_f, Queue, Sorted).

compare_f(Order, [F1|_], [F2|_]) :-
    ( F1 < F2 -> Order = <
    ; F1 > F2 -> Order = >
    ; Order = <
    ).
