extends Node2D

const SIZE := 13
const WallScene := preload("res://Wall.tscn")
const StunScene = preload("res://StunTile.tscn")
const INF := 1_000_000.0

@onready var ground: TileMapLayer   = $TileMap/TileMapLayer
@onready var walls_root: Node2D     = $TileMap/Walls
@onready var stun_root: Node2D      = $TileMap/Stun

@onready var astar_agent: Node2D    = $TileMap/AStarAgent
@onready var dijkstra_agent: Node2D = $TileMap/DijkstraAgent

@onready var score1_label: Label    = $BoxContainer/Score1   # score Dijkstra
@onready var score2_label: Label    = $BoxContainer2/Score2  # score A*

var blocked := []
var costs := []

var board_min: Vector2i
var board_max: Vector2i
var rng := RandomNumberGenerator.new()

var score_dijkstra: int = 0
var score_astar: int = 0
const STUN_COST := 3

var race_running: bool = false


func _ready() -> void:
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

	race_running = true
	astar_agent.start()
	dijkstra_agent.start()


func _init_blocked() -> void:
	blocked.resize(SIZE)
	costs.resize(SIZE)

	for y in range(SIZE):
		blocked[y] = []
		costs[y] = []
		for x in range(SIZE):
			blocked[y].append(false)
			costs[y].append(1)


func _index(c: Vector2i) -> Vector2i:
	return Vector2i(c.x - board_min.x, c.y - board_min.y)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= board_min.x and c.x <= board_max.x and c.y >= board_min.y and c.y <= board_max.y


func _is_blocked(c: Vector2i) -> bool:
	if not _in_bounds(c):
		return true
	var i: Vector2i = _index(c)
	return blocked[i.y][i.x]


func _spawn_menu_walls(count: int) -> void:
	rng.randomize()
	var tries: int = 0
	var placed: int = 0

	while placed < count and tries < count * 50:
		tries += 1
		var c := Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)
		if _is_blocked(c):
			continue
		if c == _world_to_cell(astar_agent.position) or c == _world_to_cell(dijkstra_agent.position):
			continue

		if _set_blocked(c):
			placed += 1


func _spawn_stun_tiles(count: int) -> void:
	rng.randomize()
	var tries: int = 0
	var placed: int = 0

	while placed < count and tries < count * 40:
		tries += 1
		var c := Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)

		if _is_blocked(c):
			continue
		if c == _world_to_cell(astar_agent.position) or c == _world_to_cell(dijkstra_agent.position):
			continue
		if c.y == board_min.y or c.y == board_max.y:
			continue

		var i: Vector2i = _index(c)
		costs[i.y][i.x] = STUN_COST

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


# ================== PATHFINDING WRAPPER ==================

func compute_path(start: Vector2i, goals: Array[Vector2i], mode: String) -> Array[Vector2i]:
	if mode == "astar":
		return _astar(start, goals)
	return _dijkstra(start, goals)


# ================== A* ==================

func _heuristic_to_line(a: Vector2i, goals: Array[Vector2i]) -> float:
	var best: float = INF
	for g: Vector2i in goals:
		var d: float = abs(a.x - g.x) + abs(a.y - g.y)
		if d < best:
			best = d
	return best


func _astar(start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var open: Array[Vector2i] = [start]
	var came := {}
	var g := { start: 0.0 }
	var f := { start: _heuristic_to_line(start, goals) }

	while not open.is_empty():
		open.sort_custom(func(a, b): return float(f.get(a, INF)) < float(f.get(b, INF)))
		var current: Vector2i = open.pop_front()

		if goals.has(current):
			return _reconstruct_path(came, start, current)

		for n: Vector2i in _get_neighbors(current):
			var ng: float = float(g.get(current, INF)) + float(costs[_index(n).y][_index(n).x])

			if ng < float(g.get(n, INF)):
				came[n] = current
				g[n] = ng
				f[n] = ng + _heuristic_to_line(n, goals)

				if not open.has(n):
					open.append(n)

	return []


# ================== DIJKSTRA ==================

func _dijkstra(start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var dist := { start: 0.0 }
	var prev := {}
	var open: Array[Vector2i] = [start]

	while not open.is_empty():
		open.sort_custom(func(a, b): return float(dist.get(a, INF)) < float(dist.get(b, INF)))
		var u: Vector2i = open.pop_front()

		if goals.has(u):
			return _reconstruct_path(prev, start, u)

		for v: Vector2i in _get_neighbors(u):
			var idx: Vector2i = _index(v)
			var tile_cost: float = float(costs[idx.y][idx.x])
			var alt: float = float(dist.get(u, INF)) + tile_cost
			if alt < float(dist.get(v, INF)):
				dist[v] = alt
				prev[v] = u
				if not open.has(v):
					open.append(v)

	return []


# ================== RECONSTRUCT ==================

func _reconstruct_path(prev, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur: Vector2i = goal
	while prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	path.push_front(start)
	return path


# ================== PATH EXISTENCE ==================

func _has_path(start: Vector2i, goals: Array[Vector2i]) -> bool:
	if goals.is_empty():
		return false

	var q: Array[Vector2i] = [start]
	var visited := { start: true }

	while not q.is_empty():
		var u: Vector2i = q.pop_front()
		if goals.has(u):
			return true

		for n: Vector2i in _get_neighbors(u):
			if not visited.has(n):
				visited[n] = true
				q.append(n)

	return false


# ================== WALL PLACEMENT ==================

func _set_blocked(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false

	var idx: Vector2i = _index(cell)
	if blocked[idx.y][idx.x]:
		return false

	blocked[idx.y][idx.x] = true

	var start_astar: Vector2i = _world_to_cell(astar_agent.position)
	var start_dijkstra: Vector2i = _world_to_cell(dijkstra_agent.position)

	var ok_astar: bool = _has_path(start_astar, _top_line())
	var ok_dijkstra: bool = _has_path(start_dijkstra, _bottom_line())

	if ok_astar and ok_dijkstra:
		var w := WallScene.instantiate()
		w.position = to_world(cell)
		walls_root.add_child(w)
		return true

	blocked[idx.y][idx.x] = false
	return false


# ================== SCORE + RESTART ==================

func agent_reached_goal(agent: Node2D) -> void:
	if not race_running:
		return
	race_running = false
	if agent == dijkstra_agent:
		score_dijkstra += 1
		score1_label.text = str(score_dijkstra)
	else:
		score_astar += 1
		score2_label.text = str(score_astar)

	_restart_race()



func _restart_race() -> void:
	race_running = true   # <<< FIX CRITIQUE

	dijkstra_agent.stop()
	astar_agent.stop()

	await get_tree().create_timer(0.5).timeout

	# Clear walls & stun
	for child in walls_root.get_children():
		child.queue_free()
	for child in stun_root.get_children():
		child.queue_free()

	# Reset grid
	_init_blocked()

	# Update goal lines
	astar_agent.goal_line    = _top_line()
	dijkstra_agent.goal_line = _bottom_line()

	# Spawn new walls and stun
	_spawn_menu_walls(22)
	_spawn_stun_tiles(15)

	# Reset agents
	dijkstra_agent.cell = dijkstra_agent.start_cell
	dijkstra_agent.position = to_world(dijkstra_agent.start_cell)
	dijkstra_agent.path.clear()
	dijkstra_agent.step = 0
	dijkstra_agent.stunned = false

	astar_agent.cell = astar_agent.start_cell
	astar_agent.position = to_world(astar_agent.start_cell)
	astar_agent.path.clear()
	astar_agent.step = 0
	astar_agent.stunned = false

	# Restart loop
	dijkstra_agent.start()
	astar_agent.start()
