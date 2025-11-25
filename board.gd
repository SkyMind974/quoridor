extends Node2D

const SIZE := 13
const WallScene := preload("res://Wall.tscn")
const DebugCellScene := preload("res://DebugCell.tscn")
const INF := 1_000_000.0

@onready var ground = $TileMap/TileMapLayer
@onready var player_node: Node2D = $TileMap/Player
@onready var ai_node: Node2D = $TileMap/IA
@onready var walls_root: Node2D = $TileMap/Walls
@onready var debug_root: Node2D = $TileMap/Debug

@onready var notification_panel := $UI/TextureRect
@onready var notification_label := $UI/TextureRect/Label
@onready var debug_button := $UI/Button

@onready var back := $UI/Fond
@onready var victory_panel := $UI/Victoire
@onready var victory_label := $UI/Victoire/Label
@onready var defeat_panel := $UI/Defaite
@onready var defeat_label := $UI/Defaite/Label

@onready var pause_menu: Control = $UI/MenuPanel

enum Turn { PLAYER, AI }

var notif_version := 0
var rng := RandomNumberGenerator.new()

var board_min: Vector2i
var board_max: Vector2i

var player_cell: Vector2i
var ai_cell: Vector2i

var current_turn: Turn = Turn.PLAYER
var blocked: Array = []
var last_dijkstra_dist: Dictionary = {}
var debug_enabled := true
var game_over := false


# ======================================================
# ===================   READY   ========================
# ======================================================
func _ready() -> void:
	pause_menu.visible = false
	
	notification_panel.visible = false
	notification_label.visible = false
	notification_panel.modulate.a = 1.0

	victory_panel.visible = false
	victory_label.visible = false
	defeat_panel.visible = false
	defeat_label.visible = false
	back.visible = false

	debug_button.pressed.connect(_on_debug_button_pressed)

	var used_rect: Rect2i = ground.get_used_rect()
	board_min = used_rect.position
	board_max = board_min + Vector2i(SIZE - 1, SIZE - 1)

	_init_blocked()
	rng.randomize()

	player_cell = _clamp_to_board(world_to_grid(player_node.position))
	ai_cell = _clamp_to_board(world_to_grid(ai_node.position))

	_update_positions()
	_spawn_random_walls(20)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if game_over:
			return
		_toggle_pause()

func _toggle_pause() -> void:
	if pause_menu.visible:
		get_tree().paused = false
		pause_menu.visible = false
	else:
		get_tree().paused = true
		pause_menu.visible = true

func _clamp_to_board(c: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(c.x, board_min.x, board_max.x),
		clampi(c.y, board_min.y, board_max.y)
	)

func world_to_grid(pos: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(pos))

func grid_to_world(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))

func _init_blocked() -> void:
	blocked.resize(SIZE)
	for y in SIZE:
		var row: Array[bool] = []
		for x in SIZE:
			row.append(false)
		blocked[y] = row

func _index(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - board_min.x, cell.y - board_min.y)

func _is_blocked(cell: Vector2i) -> bool:
	var idx := _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		return true
	return blocked[idx.y][idx.x]

func _can_move(c: Vector2i) -> bool:
	return _in_bounds(c) and not _is_blocked(c)

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= board_min.x and c.x <= board_max.x and c.y >= board_min.y and c.y <= board_max.y

func _update_positions() -> void:
	player_node.position = grid_to_world(player_cell)
	ai_node.position = grid_to_world(ai_cell)


# ======================================================
# ===================   NOTIFS   =======================
# ======================================================
func _show_notification(text: String) -> void:
	notif_version += 1
	var id := notif_version

	notification_label.text = text
	notification_label.visible = true          # <- important
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0
	notification_label.modulate.a = 1.0       # au cas où

	await get_tree().create_timer(1.2).timeout
	if id != notif_version:
		return

	var t := create_tween()
	t.tween_property(notification_panel, "modulate:a", 0.0, 0.5)
	await t.finished

	if id == notif_version:
		notification_panel.visible = false
		notification_label.visible = false


# ===================   WALLS   ========================
func _set_blocked(cell: Vector2i, show_notif := true) -> bool:
	var idx := _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		if show_notif:
			_show_notification("Impossible ici")
		return false

	if blocked[idx.y][idx.x]:
		if show_notif:
			_show_notification("Déjà un mur")
		return false

	blocked[idx.y][idx.x] = true

	var ok_ai := _has_path(ai_cell, _ai_goal_cells())
	var ok_player := _has_path(player_cell, _player_goal_cells())

	if ok_ai and ok_player:
		var wall := WallScene.instantiate()
		wall.position = grid_to_world(cell)
		walls_root.add_child(wall)
		return true

	blocked[idx.y][idx.x] = false

	if show_notif:
		_show_notification("Tu bloques totalement")

	return false


func _spawn_random_walls(count: int) -> void:
	var placed := 0
	var tries := 0

	while placed < count and tries < count * 40:
		tries += 1
		var c := Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)

		if c == player_cell or c == ai_cell:
			continue

		if _set_blocked(c, false):
			placed += 1


# ================= PATHFINDING ========================
func compute_path(start: Vector2i, goals: Array[Vector2i], debug: bool) -> Array[Vector2i]:
	if GameSettings.algo_mode == GameSettings.Algo.DIJKSTRA:
		return _dijkstra(start, goals, debug)
	else:
		return _astar(start, goals, debug)


func _get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if _can_move(n):
			r.append(n)
	return r


func _ai_goal_cells() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		var c: Vector2i = Vector2i(x, board_max.y)
		if not _is_blocked(c):
			r.append(c)
	return r


func _player_goal_cells() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x + 1):
		var c: Vector2i = Vector2i(x, board_min.y)
		if not _is_blocked(c):
			r.append(c)
	return r


func _has_path(start: Vector2i, goals: Array[Vector2i]) -> bool:
	if goals.is_empty():
		return false

	var q: Array[Vector2i] = [start]
	var visited := {start: true}

	while not q.is_empty():
		var u: Vector2i = q.pop_front()
		if goals.has(u):
			return true

		for n in _get_neighbors(u):
			if not visited.has(n):
				visited[n] = true
				q.append(n)

	return false


# ================= DIJKSTRA ===========================
func _dijkstra(start: Vector2i, goals: Array[Vector2i], debug := true) -> Array[Vector2i]:
	var dist := {start: 0.0}
	var prev := {}
	var q: Array[Vector2i] = [start]

	var found := false
	var goal: Vector2i = start

	while not q.is_empty():
		q.sort_custom(func(a, b): return dist.get(a, INF) < dist.get(b, INF))
		var u: Vector2i = q.pop_front()

		if goals.has(u):
			goal = u
			found = true
			break

		for v in _get_neighbors(u):
			var alt: float = float(dist.get(u, INF)) + 1.0
			if alt < float(dist.get(v, INF)):
				dist[v] = alt
				prev[v] = u
				if not q.has(v):
					q.append(v)

	if debug:
		last_dijkstra_dist = dist
		_draw_debug()

	if not found:
		return []

	return _reconstruct(prev, start, goal)


# ================= A* =================================
func _heuristic(a: Vector2i, goals: Array[Vector2i]) -> float:
	var best: float = INF
	for g in goals:
		var d: int = abs(a.x - g.x) + abs(a.y - g.y)
		if d < best:
			best = d
	return best


func _astar(start: Vector2i, goals: Array[Vector2i], debug := true) -> Array[Vector2i]:
	var open: Array[Vector2i] = [start]
	var came := {}
	var g := {start: 0.0}
	var f := {start: _heuristic(start, goals)}
	var visited := {}

	var found := false
	var goal: Vector2i = start

	while not open.is_empty():
		open.sort_custom(func(a, b): return f.get(a, INF) < f.get(b, INF))
		var current: Vector2i = open.pop_front()
		visited[current] = g.get(current, INF)

		if goals.has(current):
			goal = current
			found = true
			break

		for n in _get_neighbors(current):
			var ng: float = float(g.get(current, INF)) + 1.0

			if ng < float(g.get(n, INF)):
				came[n] = current
				g[n] = ng
				f[n] = ng + _heuristic(n, goals)

				if not open.has(n):
					open.append(n)

	if debug:
		last_dijkstra_dist = visited
		_draw_debug()

	if not found:
		return []

	return _reconstruct(came, start, goal)


# ================ DEBUG DRAW ==========================
func _draw_debug() -> void:
	for c in debug_root.get_children():
		c.queue_free()

	if not debug_enabled:
		return

	for cell in last_dijkstra_dist.keys():
		var d = DebugCellScene.instantiate()
		d.position = grid_to_world(cell)

		if d.has_node("Label"):
			var lbl: Label = d.get_node("Label")
			var v = last_dijkstra_dist[cell]
			lbl.text = str(int(v))

		debug_root.add_child(d)



# ================= RECONSTRUCT ========================
func _reconstruct(prev: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	var cur: Vector2i = goal

	while prev.has(cur):
		p.push_front(cur)
		cur = prev[cur]

	p.push_front(start)
	return p


# ================= TURN SYSTEM ========================
func _end_player_turn() -> void:
	if _check_victory():
		return
	current_turn = Turn.AI
	ai_node.play_turn()

func end_ai_turn() -> void:
	if _check_victory():
		return
	current_turn = Turn.PLAYER

func _check_victory():
	if player_cell.y == board_min.y:
		_show_victory(true)
		return true

	if ai_cell.y == board_max.y:
		_show_victory(false)
		return true

	return false

func _show_victory(p: bool) -> void:
	game_over = true
	back.visible = true
	get_tree().paused = false
	pause_menu.visible = false

	if p:
		victory_panel.visible = true
		victory_label.visible = true
		defeat_panel.visible = false
	else:
		defeat_panel.visible = true
		defeat_label.visible = true
		victory_panel.visible = false



# ================= PLAYER INPUT =======================
func request_player_move(dir: Vector2i) -> void:
	if game_over:
		return
	if current_turn != Turn.PLAYER:
		return

	var t := player_cell + dir
	if _can_move(t):
		player_cell = t
		_update_positions()
		_end_player_turn()

func request_player_place_wall(cell: Vector2i) -> void:
	if game_over:
		return
	if current_turn != Turn.PLAYER:
		return

	if _set_blocked(cell, true):
		_update_positions()
		_end_player_turn()

func _on_debug_button_pressed() -> void:
	debug_enabled = !debug_enabled
	_draw_debug()


func _on_retry_pressed() -> void:
	game_over = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menu/Menu_scene.tscn")
