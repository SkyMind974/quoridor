extends Node

enum Algo {
	ASTAR,
	DIJKSTRA
}

enum Mode {
	VS_IA,
	MULTI
}

var algo_mode: Algo = Algo.ASTAR
var game_mode: Mode = Mode.VS_IA
