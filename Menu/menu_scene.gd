extends Node2D

const SIZE := 13
const WallScene := preload("res://Wall.tscn")
const StunScene = preload("res://StunTile.tscn")
const INF := 1_000_000.0

@onready var ground: TileMapLayer   = $TileMap/TileMapLayer
@onready var walls_root: Node2D     = $TileMap/Walls
@onready var stun_root: Node2D     = $TileMap/Stun

@onready var astar_agent: Node2D    = $TileMap/AStarAgent
@onready var dijkstra_agent: Node2D = $TileMap/DijkstraAgent

@onready var score1_label: Label    = $Score1   # score Dijkstra
@onready var score2_label: Label    = $Score2   # score A*

var blocked := []
var board_min: Vector2i
var board_max: Vector2i
var rng := RandomNumberGenerator.new()

var score_dijkstra: int = 0
var score_astar: int = 0
var costs := []
const STUN_COST := 3


func _ready():
	var used: Rect2i = ground.get_used_rect()
	board_min = used.position
	board_max = used.position + used.size - Vector2i(1, 1)

	_init_blocked()
	_spawn_menu_walls(22)
	_spawn_stun_tiles(15)

	astar_agent.board = self
	dijkstra_agent.board = self

	astar_agent.start_cell    = _world_to_cell(astar_agent.position)
	dijkstra_agent.start_cell = _world_to_cell(dijkstra_agent.position)

	astar_agent.goal_line    = _top_line()
	dijkstra_agent.goal_line = _bottom_line()

	astar_agent.mode    = "astar"
	dijkstra_agent.mode = "dijkstra"

	score1_label.text = "0"
	score2_label.text = "0"

	astar_agent.start()
	dijkstra_agent.start()


func _init_blocked():
	blocked.resize(SIZE)
	costs.resize(SIZE)

	for y in SIZE:
		blocked[y] = []
		costs[y] = []
		for x in SIZE:
			blocked[y].append(false)
			costs[y].append(1)



func _index(c: Vector2i) -> Vector2i:
	return Vector2i(c.x - board_min.x, c.y - board_min.y)


func _is_blocked(c: Vector2i) -> bool:
	var i := _index(c)
	if i.x < 0 or i.x >= SIZE or i.y < 0 or i.y >= SIZE:
		return true
	return blocked[i.y][i.x]


func _spawn_menu_walls(count: int):
	rng.randomize()
	var tries = 0
	var placed = 0

	while placed < count and tries < count * 50:
		tries += 1
		var c = Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)
		if _is_blocked(c):
			continue
		if c == astar_agent.start_cell or c == dijkstra_agent.start_cell:
			continue

		var idx := _index(c)
		blocked[idx.y][idx.x] = true

		var w = WallScene.instantiate()
		w.position = to_world(c)
		walls_root.add_child(w)

		placed += 1
		
func _spawn_stun_tiles(count: int):
	rng.randomize()
	var tries := 0
	var placed := 0

	while placed < count and tries < count * 40:
		tries += 1
		var c := Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)

		var i := _index(c)

		# interdit :
		# les cases bloquées
		# les cases de départ IA / Dijkstra
		# les lignes de but
		if _is_blocked(c):
			continue
		if c == astar_agent.start_cell or c == dijkstra_agent.start_cell:
			continue
		if c.y == board_min.y or c.y == board_max.y:
			continue

		# APPLIQUER LE COÛT
		costs[i.y][i.x] = STUN_COST

		# INSTANTIATE VISUEL
		var stun := StunScene.instantiate()
		stun.position = to_world(c)
		stun_root.add_child(stun)

		placed += 1



func _world_to_cell(pos: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(pos))


func to_world(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func _get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var n: Vector2i = c + d
		if not _is_blocked(n):
			r.append(n)
	return r


func _top_line() -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		arr.append(Vector2i(x, board_min.y))
	return arr


func _bottom_line() -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		arr.append(Vector2i(x, board_max.y))
	return arr


# ========== A* ou Dijkstra appelés par agent ==========

func compute_path(start: Vector2i, goals: Array[Vector2i], mode: String) -> Array[Vector2i]:
	if mode == "astar":
		return _astar(start, goals)
	else:
		return _dijkstra(start, goals)


# --------------------- A* -----------------------------

func _heuristic_to_line(a: Vector2i, goals: Array[Vector2i]) -> float:
	var best := INF
	for g in goals:
		var d: float = abs(a.x - g.x) + abs(a.y - g.y)
		if d < best:
			best = d
	return best


func _astar(start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var open = [start]
	var came = {}
	var g = { start: 0.0 }
	var f = { start: _heuristic_to_line(start, goals) }

	while not open.is_empty():
		open.sort_custom(func(a, b):
			return float(f.get(a, INF)) < float(f.get(b, INF))
		)
		var current: Vector2i = open.pop_front()

		# si on est arrivé
		if goals.has(current):
			return _reconstruct_path(came, start, current)

		for n in _get_neighbors(current):
			var ng = g.get(current, INF) + 1.0  # A* ignore le coût stun

			if ng < g.get(n, INF):
				came[n] = current
				g[n] = ng
				f[n] = ng + _heuristic_to_line(n, goals)

				if not open.has(n):
					open.append(n)

	return []


# ------------------ Dijkstra --------------------------

func _dijkstra(start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var dist = { start: 0.0 }
	var prev = {}
	var open = [start]

	while not open.is_empty():
		open.sort_custom(func(a, b):
			return float(dist.get(a, INF)) < float(dist.get(b, INF))
		)
		var u: Vector2i = open.pop_front()

		if goals.has(u):
			return _reconstruct_path(prev, start, u)

		for v in _get_neighbors(u):
			var i := _index(v)
			var tile_cost := float(costs[i.y][i.x])
			var alt = dist.get(u, INF) + tile_cost
			if alt < dist.get(v, INF):
				dist[v] = alt
				prev[v] = u
				if not open.has(v):
					open.append(v)

	return []


# ---------------- Reconstruction -----------------------

func _reconstruct_path(prev, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur: Vector2i = goal
	while prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	path.push_front(start)
	return path


# =====================================================
# =============== SCORE + RESTART ======================
# =====================================================

func agent_reached_goal(agent: Node2D) -> void:
	if agent == dijkstra_agent:
		score_dijkstra += 1
		score1_label.text = str(score_dijkstra)
	elif agent == astar_agent:
		score_astar += 1
		score2_label.text = str(score_astar)
	else:
		return

	_restart_race()


func _restart_race() -> void:
	dijkstra_agent.stop()
	astar_agent.stop()

	await get_tree().create_timer(1.0).timeout

	for child in walls_root.get_children():
		child.queue_free()
	for child in stun_root.get_children():
		child.queue_free()
	_init_blocked()
	_spawn_menu_walls(22)
	_spawn_stun_tiles(15)

	astar_agent.start()
	dijkstra_agent.start()
