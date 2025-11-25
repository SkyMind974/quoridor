extends Node2D

const SIZE := 13
const WallScene := preload("res://Wall.tscn")
const DebugCellScene := preload("res://DebugCell.tscn")
const INF := 1_000_000.0

@onready var ground = $TileMap/TileMapLayer
@onready var player: Node2D = $TileMap/Player
@onready var ai: Node2D = $TileMap/IA
@onready var walls_root: Node2D = $TileMap/Walls
@onready var debug_root: Node2D = $TileMap/Debug

@onready var notification_panel: TextureRect = $UI/TextureRect
@onready var notification_label: Label = $UI/TextureRect/Label
@onready var debug_button: Button = $UI/Button

@onready var back: TextureRect =  $UI/Fond

@onready var victory_panel: TextureRect = $UI/Victoire
@onready var victory_label: Label = $UI/Victoire/Label

@onready var defeat_panel: TextureRect = $UI/Defaite
@onready var defeat_label: Label =  $UI/Defaite/Label

enum Turn { PLAYER, AI }

var notif_version := 0
var rng := RandomNumberGenerator.new()
var board_min: Vector2i
var board_max: Vector2i
var player_cell: Vector2i
var ai_cell: Vector2i
var current_turn: Turn = Turn.PLAYER
var blocked: Array = []
var last_dijkstra_dist := {}
var debug_enabled := true
var game_over := false


func _show_notification(text: String) -> void:
	notif_version += 1
	var my_version := notif_version

	notification_label.text = text
	notification_panel.visible = true
	notification_label.visible = true
	notification_panel.modulate.a = 1.0

	var timer := get_tree().create_timer(1.2)
	await timer.timeout
	if my_version != notif_version:
		return

	var tween := create_tween()
	tween.tween_property(notification_panel, "modulate:a", 0.0, 0.5)
	await tween.finished
	if my_version == notif_version:
		_hide_notification()


func _hide_notification() -> void:
	notification_panel.visible = false
	notification_label.visible = false
	notification_panel.modulate.a = 1.0


func _ready():
	notification_panel.visible = false
	notification_label.visible = false
	notification_panel.modulate.a = 1.0

	victory_panel.visible = false
	victory_label.visible = false
	defeat_label.visible = false
	defeat_panel.visible = false
	back.visible = false
	
	debug_button.pressed.connect(_on_debug_button_pressed)


	var used_rect: Rect2i = ground.get_used_rect()
	board_min = used_rect.position
	board_max = board_min + Vector2i(SIZE - 1, SIZE - 1)

	_init_blocked()
	rng.randomize()

	player_cell = world_to_grid(player.position)
	player_cell.x = clampi(player_cell.x, board_min.x, board_max.x)
	player_cell.y = clampi(player_cell.y, board_min.y, board_max.y)

	ai_cell = world_to_grid(ai.position)
	ai_cell.x = clampi(ai_cell.x, board_min.x, board_max.x)
	ai_cell.y = clampi(ai_cell.y, board_min.y, board_max.y)

	_update_all_positions()
	_spawn_random_walls(20)


func _spawn_random_walls(count: int):
	var tries := 0
	var placed := 0
	var max_tries := count * 30

	while placed < count and tries < max_tries:
		tries += 1
		var x = rng.randi_range(board_min.x, board_max.x)
		var y = rng.randi_range(board_min.y, board_max.y)
		var cell := Vector2i(x, y)

		if cell == player_cell or cell == ai_cell:
			continue

		if _set_blocked(cell, false):
			placed += 1


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


func _set_blocked(cell: Vector2i, show_notif := true) -> bool:
	var idx = _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		if show_notif:
			_show_notification("Tu ne peux pas poser de mur ici")
		return false
	if blocked[idx.y][idx.x]:
		if show_notif:
			_show_notification("Tu ne peux pas poser de mur ici")
		return false

	blocked[idx.y][idx.x] = true

	var ok_ai = _has_path(ai_cell, _ai_goal_cells())
	var ok_player = _has_path(player_cell, _player_goal_cells())

	if ok_ai and ok_player:
		var wall = WallScene.instantiate()
		wall.position = grid_to_world(cell)
		walls_root.add_child(wall)
		if show_notif:
			_hide_notification()
		return true

	blocked[idx.y][idx.x] = false
	if show_notif:
		_show_notification("Tu ne peux pas poser ici")
	return false


func _update_all_positions():
	player.position = grid_to_world(player_cell)
	ai.position = grid_to_world(ai_cell)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= board_min.x and c.x <= board_max.x and c.y >= board_min.y and c.y <= board_max.y


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


func _ai_goal_cells() -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		var c = Vector2i(x, board_max.y)
		if not _is_blocked(c):
			res.append(c)
	return res


func _player_goal_cells() -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		var c = Vector2i(x, board_min.y)
		if not _is_blocked(c):
			res.append(c)
	return res


func _has_path(start: Vector2i, goals: Array[Vector2i]) -> bool:
	if goals.is_empty():
		return false

	var visited := {}
	var queue: Array[Vector2i] = []

	visited[start] = true
	queue.append(start)

	while not queue.is_empty():
		var u: Vector2i = queue.pop_front()
		if goals.has(u):
			return true
		for v in _get_neighbors(u):
			if not visited.has(v):
				visited[v] = true
				queue.append(v)

	return false


func _dijkstra_path(start: Vector2i, goals: Array[Vector2i], debug := true) -> Array[Vector2i]:
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

	if debug:
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


func _update_dijkstra_debug():
	for child in debug_root.get_children():
		child.queue_free()

	if not debug_enabled:
		return

	for cell in last_dijkstra_dist.keys():
		var d = DebugCellScene.instantiate()
		d.position = grid_to_world(cell)
		debug_root.add_child(d)


func _unhandled_input(event):
	if game_over:
		return
	if current_turn != Turn.PLAYER:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_pos: Vector2 = get_global_mouse_position()
		var local = ground.to_local(world_pos)
		var cell: Vector2i = ground.local_to_map(local)

		if _in_bounds(cell) and cell != player_cell and cell != ai_cell:
			if _set_blocked(cell, true):
				_update_all_positions()
				_end_player_turn()
		return

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


func _check_victory() -> bool:
	if player_cell.y == board_min.y:
		_show_victory(true)
		return true
	if ai_cell.y == board_max.y:
		_show_victory(false)
		return true
	return false


func _show_victory(player_won: bool) -> void:
	game_over = true
	back.visible = true
	if player_won:
		victory_panel.visible = true
		victory_label.visible = true
	else:
		defeat_panel.visible = true
		defeat_label.visible = true


func _end_player_turn():
	if _check_victory():
		return
	current_turn = Turn.AI
	ai_play()


func ai_play():
	if game_over:
		return

	var ai_goals = _ai_goal_cells()
	var ai_path = _dijkstra_path(ai_cell, ai_goals, debug_enabled)

	var player_goals = _player_goal_cells()
	var player_path = _dijkstra_path(player_cell, player_goals, false)

	var placed_wall := false

	if player_path.size() > 1 and ai_path.size() > 0 and player_path.size() <= ai_path.size():
		var max_check: int = min(player_path.size(), 5)
		for i in range(1, max_check):
			var c: Vector2i = player_path[i]
			if c == ai_cell or c == player_cell:
				continue
			if _is_blocked(c):
				continue
			if _set_blocked(c, false):
				placed_wall = true
				break

	if placed_wall:
		_update_all_positions()
		_end_ai_turn()
		return

	if ai_path.size() > 1:
		ai_cell = ai_path[1]

	_update_all_positions()
	_end_ai_turn()


func _end_ai_turn():
	if _check_victory():
		return
	current_turn = Turn.PLAYER


func _on_debug_button_pressed():
	debug_enabled = not debug_enabled
	_update_dijkstra_debug()
