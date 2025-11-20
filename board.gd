extends Node2D

const SIZE := 13
const WallScene := preload("res://Wall.tscn")
const INF := 1_000_000.0

@onready var debug_layer = $TileMap/DebugLayer

var last_dijkstra_dist := {}


@onready var ground = $TileMap/TileMapLayer
@onready var player: Node2D = $TileMap/Player
@onready var ai: Node2D = $TileMap/IA
@onready var walls_root: Node2D = $TileMap/Walls

enum Turn { PLAYER, AI }

var board_min: Vector2i
var board_max: Vector2i

var player_cell: Vector2i
var ai_cell: Vector2i

var current_turn: Turn = Turn.PLAYER

var blocked: Array = []


func _ready():
	var used_rect: Rect2i = ground.get_used_rect()
	board_min = used_rect.position
	board_max = board_min + Vector2i(SIZE - 1, SIZE - 1)

	_init_blocked()

	player_cell = world_to_grid(player.position)
	player_cell.x = clampi(player_cell.x, board_min.x, board_max.x)
	player_cell.y = clampi(player_cell.y, board_min.y, board_max.y)

	ai_cell = world_to_grid(ai.position)
	ai_cell.x = clampi(ai_cell.x, board_min.x, board_max.x)
	ai_cell.y = clampi(ai_cell.y, board_min.y, board_max.y)

	_update_all_positions()


func _init_blocked():
	blocked.resize(SIZE)
	for y in SIZE:
		blocked[y] = []
		for x in SIZE:
			blocked[y].append(false)


func world_to_grid(pos: Vector2) -> Vector2i:
	var local = ground.to_local(pos)
	return ground.local_to_map(local)


func grid_to_world(cell: Vector2i) -> Vector2:
	var local = ground.map_to_local(cell)
	return ground.to_global(local)


func _index(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - board_min.x, cell.y - board_min.y)


func _is_blocked(cell: Vector2i) -> bool:
	var idx = _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		return true
	return blocked[idx.y][idx.x]


func _set_blocked(cell: Vector2i):
	var idx = _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		return
	if blocked[idx.y][idx.x]:
		return

	blocked[idx.y][idx.x] = true

	var wall = WallScene.instantiate()
	wall.position = grid_to_world(cell)
	walls_root.add_child(wall)


func _update_all_positions():
	player.position = grid_to_world(player_cell)
	ai.position = grid_to_world(ai_cell)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= board_min.x and c.x <= board_max.x \
		and c.y >= board_min.y and c.y <= board_max.y


func _can_move(to: Vector2i) -> bool:
	if not _in_bounds(to):
		return false
	if _is_blocked(to):
		return false
	return true
func _get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n = c + dir
		if _can_move(n):
			res.append(n)
	return res


func _get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n = c + dir
		if _can_move(n):
			res.append(n)
	return res


func _ai_goal_cells() -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		var c = Vector2i(x, board_max.y)
		if not _is_blocked(c):
			res.append(c)
	return res


func _dijkstra_path(start: Vector2i, goals: Array[Vector2i]) -> Array[Vector2i]:
	var dist := {}
	var prev := {}
	var q: Array[Vector2i] = []

	dist[start] = 0.0
	q.append(start)

	var goal := start
	var found := false

	while not q.is_empty():
		q.sort_custom(func(a, b): return dist.get(a, INF) < dist.get(b, INF))
		var u: Vector2i = q.pop_front()
		if goals.has(u):
			goal = u
			found = true
			break
		for v in _get_neighbors(u):
			var alt = dist[u] + 1.0
			if alt < dist.get(v, INF):
				dist[v] = alt
				prev[v] = u
				if not q.has(v):
					q.append(v)

	last_dijkstra_dist = dist
	_update_dijkstra_debug()

	if not found:
		return []

	var path: Array[Vector2i] = []
	var cur = goal
	while prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	path.push_front(start)
	return path


func _unhandled_input(event):
	if current_turn != Turn.PLAYER:
		return

	# clic gauche -> poser un mur sur la case
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_pos: Vector2 = get_global_mouse_position()
		var local = ground.to_local(world_pos)
		var cell: Vector2i = ground.local_to_map(local)

		if _in_bounds(cell) and not _is_blocked(cell) and cell != player_cell and cell != ai_cell:
			_set_blocked(cell)
			_update_all_positions()
			_end_player_turn()
		return

	# ZQSD / flèches -> déplacer le joueur
	if event is InputEventKey and event.pressed:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:
				dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN:
				dir = Vector2i(0, 1)
			KEY_A, KEY_LEFT:
				dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT:
				dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			var target := player_cell + dir
			if _can_move(target):
				player_cell = target
				_update_all_positions()
				_end_player_turn()


func _end_player_turn():
	current_turn = Turn.AI
	ai_play()


func ai_play():
	var goals = _ai_goal_cells()
	var path = _dijkstra_path(ai_cell, goals)
	if path.size() > 1:
		ai_cell = path[1]
	_update_all_positions()
	_end_ai_turn()



func _end_ai_turn():
	current_turn = Turn.PLAYER
