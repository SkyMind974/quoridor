extends Node2D

const SIZE: int = 13
const WallScene := preload("res://Wall.tscn")
const StunScene := preload("res://StunTile.tscn")
const DebugCellScene := preload("res://DebugCell.tscn")
const INF: float = 1_000_000.0

@onready var ground: TileMapLayer = $TileMap/TileMapLayer
@onready var player_node: Node2D = $TileMap/Player
@onready var ai_node: Node2D = $TileMap/IA
@onready var walls_root: Node2D = $TileMap/Walls
@onready var debug_root: Node2D = $TileMap/Debug

@onready var notification_panel: TextureRect = $UI/TextureRect
@onready var notification_label: Label = $UI/TextureRect/Label
@onready var debug_button: Button = $UI/Button

@onready var back: TextureRect = $UI/Menu/Fond
@onready var victory_panel: Control = $UI/Menu/Victoire
@onready var victory_label: Label = $UI/Menu/Victoire/Label
@onready var defeat_panel: Control = $UI/Menu/Defaite
@onready var defeat_label: Label = $UI/Menu/Defaite/Label
@onready var Menu: Control = $UI/Menu
@onready var pause_menu: Control = $UI/Menu/MenuPanel
@onready var help_menu: Control = $UI/Menu/HelpPanel
@onready var help: Control = $UI/Help

@onready var turn_label: Label = $UI/TurnLabel
var player1_name: String = ""
var player2_name: String = ""

var turn_count: int = 1

enum Turn { PLAYER, AI }

var notif_version: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var board_min: Vector2i
var board_max: Vector2i

var player_cell: Vector2i
var ai_cell: Vector2i

var current_turn: Turn = Turn.PLAYER
var blocked: Array = []
var costs: Array = []
var last_dijkstra_dist: Dictionary = {}
var debug_enabled: bool = true
var game_over: bool = false
var player_stunned: bool = false
var ai_stunned: bool = false

func _ready() -> void:
	player1_name = "Joueur rouge"
	player2_name = "Joueur bleu"

	pause_menu.visible = false
	notification_panel.visible = false
	notification_label.visible = false
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

	update_turn_indicator()
	_update_positions()

	_spawn_random_walls(20)
	_spawn_random_stun(20)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not game_over:
			_toggle_pause()
func _toggle_pause() -> void:
	if Menu.visible:
		get_tree().paused = false
		pause_menu.visible = false
		help_menu.visible = false
		help.visible = false
		Menu.visible = false
	else:
		get_tree().paused = true
		help.visible = false
		Menu.visible = true
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
	costs.resize(SIZE)
	for y in SIZE:
		blocked[y] = []
		costs[y] = []
		for x in SIZE:
			blocked[y].append(false)
			costs[y].append(1)

func _index(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - board_min.x, cell.y - board_min.y)

func _is_blocked(cell: Vector2i) -> bool:
	var idx: Vector2i = _index(cell)
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

func _show_notification(text: String) -> void:
	notif_version += 1
	var id: int = notif_version
	notification_label.text = text
	notification_label.visible = true
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0

	await get_tree().create_timer(1.2).timeout
	if id != notif_version:
		return

	var t: Tween = create_tween()
	t.tween_property(notification_panel, "modulate:a", 0.0, 0.5)
	await t.finished

	if id == notif_version:
		notification_panel.visible = false
		notification_label.visible = false

func _set_blocked(cell: Vector2i, show_notif := true) -> bool:
	var idx: Vector2i = _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		if show_notif:
			_show_notification("Impossible ici")
		return false

	if blocked[idx.y][idx.x]:
		if show_notif:
			_show_notification("Déjà un mur")
		return false

	blocked[idx.y][idx.x] = true

	var ok_ai: bool = _has_path(ai_cell, _ai_goal_cells())
	var ok_player: bool = _has_path(player_cell, _player_goal_cells())

	if ok_ai and ok_player:
		var wall: Node2D = WallScene.instantiate()
		wall.position = grid_to_world(cell)
		walls_root.add_child(wall)
		return true

	blocked[idx.y][idx.x] = false
	if show_notif:
		_show_notification("Tu bloques totalement")
	return false

func set_stun_cell(cell: Vector2i, cost: int = 3) -> void:
	var idx: Vector2i = _index(cell)
	if idx.x < 0 or idx.x >= SIZE or idx.y < 0 or idx.y >= SIZE:
		return
	costs[idx.y][idx.x] = cost
	var s: Node2D = StunScene.instantiate()
	s.position = grid_to_world(cell)
	walls_root.add_child(s)

func _spawn_random_stun(count: int) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 40:
		tries += 1
		var c: Vector2i = Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)
		if c == player_cell or c == ai_cell:
			continue
		if _is_blocked(c):
			continue
		var idx: Vector2i = _index(c)
		if costs[idx.y][idx.x] != 1:
			continue
		set_stun_cell(c, 3)
		placed += 1

func _spawn_random_walls(count: int) -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 40:
		tries += 1
		var c: Vector2i = Vector2i(
			rng.randi_range(board_min.x, board_max.x),
			rng.randi_range(board_min.y, board_max.y)
		)
		if c == player_cell or c == ai_cell:
			continue
		if _set_blocked(c, false):
			placed += 1

func compute_path(start: Vector2i, goals: Array, debug: bool):
	if GameSettings.algo_mode == GameSettings.Algo.DIJKSTRA:
		return _dijkstra(start, goals, debug)
	else:
		return _astar(start, goals, debug)

func _get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var n: Vector2i = c + d
		if _can_move(n):
			r.append(n)
	return r

func _ai_goal_cells() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x+1):
		var c: Vector2i = Vector2i(x, board_max.y)
		if not _is_blocked(c):
			r.append(c)
	return r

func _player_goal_cells() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for x in range(board_min.x, board_max.x+1):
		var c: Vector2i = Vector2i(x, board_min.y)
		if not _is_blocked(c):
			r.append(c)
	return r

func _has_path(start: Vector2i, goals: Array[Vector2i]) -> bool:
	var q: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	while not q.is_empty():
		var u: Vector2i = q.pop_front()
		if goals.has(u):
			return true
		for n in _get_neighbors(u):
			if not visited.has(n):
				visited[n] = true
				q.append(n)
	return false

# ===================== DIJKSTRA =====================
# Objectif : trouver le chemin le moins cher jusqu’à la destination.
# Chaque case a un coût réel (ex : normal = 1, stun = 3).
# Je mémorise pour chaque case sa distance totale depuis le départ.
# Je démarre avec la case de départ (coût = 0).
# À chaque étape, je choisis la case non traitée la moins coûteuse.
# Pour chaque voisin :
# SI aller dessus donne un coût total plus faible
# > ALORS je mets à jour son coût et son parent.
# Je continue jusqu’à atteindre la case but.
# ==============================================================================

# ======================== A* ========================
# Même objectif que Dijkstra mais en allant plus vite.
# J’ajoute une estimation de la distance restante avec une heuristique h.
# Pour chaque case, je garde :
# g = coût réel depuis le départ
# h = distance estimée jusqu’au but
# f = g + h (score de priorité)
# Je choisis toujours la case avec le plus petit f.
# Pour chaque voisin :
# SI le nouveau g est meilleur
# > ALORS je mets à jour g, h, f et son parent.
# Si j’atteins la case but : terminé.
# ==============================================================================


func _dijkstra(start: Vector2i, goals: Array[Vector2i], debug: bool = true) -> Array[Vector2i]:
	var dist: Dictionary = {start: 0.0}
	var prev: Dictionary = {}
	var q: Array[Vector2i] = [start]
	var found: bool = false
	var goal: Vector2i = start

	while not q.is_empty():
		q.sort_custom(func(a, b): return dist.get(a, INF) < dist.get(b, INF))
		var u: Vector2i = q.pop_front()

		if goals.has(u):
			goal = u
			found = true
			break

		for v in _get_neighbors(u):
			var idx: Vector2i = _index(v)
			var tile_cost: float = float(costs[idx.y][idx.x])
			var alt: float = float(dist.get(u, INF)) + tile_cost

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

func _heuristic(a: Vector2i, goals: Array[Vector2i]) -> float:
	var best: float = INF
	for g in goals:
		var d: int = abs(a.x - g.x) + abs(a.y - g.y)
		if float(d) < best:
			best = float(d)
	return best

func _astar(start: Vector2i, goals: Array[Vector2i], debug: bool = true) -> Array[Vector2i]:
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var g_cost: Dictionary = {start: 0.0}
	var f_cost: Dictionary = {start: _heuristic(start, goals)}
	var visited: Dictionary = {}
	var found: bool = false
	var goal: Vector2i = start

	while not open.is_empty():
		open.sort_custom(func(a, b): return f_cost.get(a, INF) < f_cost.get(b, INF))
		var current: Vector2i = open.pop_front()
		visited[current] = g_cost.get(current, INF)

		if goals.has(current):
			goal = current
			found = true
			break

		for n in _get_neighbors(current):
			var idx: Vector2i = _index(n)
			var tile_cost: float = float(costs[idx.y][idx.x])
			var ng: float = float(g_cost.get(current, INF)) + tile_cost

			if ng < float(g_cost.get(n, INF)):
				came[n] = current
				g_cost[n] = ng
				f_cost[n] = ng + _heuristic(n, goals)

				if not open.has(n):
					open.append(n)

	if debug:
		last_dijkstra_dist = visited
		_draw_debug()

	if not found:
		return []

	return _reconstruct(came, start, goal)

func _draw_debug() -> void:
	for c in debug_root.get_children():
		c.queue_free()

	if not debug_enabled:
		return

	for cell in last_dijkstra_dist.keys():
		var d: Node2D = DebugCellScene.instantiate()
		d.position = grid_to_world(cell)
		if d.has_node("Label"):
			var lbl: Label = d.get_node("Label")
			lbl.text = str(int(last_dijkstra_dist[cell]))
		debug_root.add_child(d)

func _reconstruct(prev: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	var cur: Vector2i = goal

	while prev.has(cur):
		p.push_front(cur)
		cur = prev[cur]

	p.push_front(start)
	return p

func _end_player_turn() -> void:
	if _check_victory():
		return

	current_turn = Turn.AI
	update_turn_indicator()
	_start_turn()



func _start_turn() -> void:
	if current_turn == Turn.PLAYER:
		# Joueur stun
		if player_stunned:
			player_stunned = false
			_show_notification(player2_name + " est étourdi !")
			current_turn = Turn.AI
			update_turn_indicator()
			return _start_turn()  # On lance le tour de l'IA

		# Joueur NON stun → il peut jouer
		return

	if current_turn == Turn.AI:
		# IA stun (ou joueur bleu en 1v1)
		if ai_stunned:
			ai_stunned = false
			_show_notification(player1_name + " est étourdi !")
			
			turn_count += 1
			update_turn_label()
			
			current_turn = Turn.PLAYER
			update_turn_indicator()
			return _start_turn()  # On renvoie la main au joueur

		# IA NON stun → elle joue normalement
		ai_node.play_turn()

func end_ai_turn() -> void:
	if _check_victory():
		return

	turn_count += 1
	update_turn_label()

	current_turn = Turn.PLAYER
	update_turn_indicator()
	_start_turn()




func _check_victory() -> bool:
	if player_cell.y == board_min.y:
		_show_victory(true)
		return true

	if ai_cell.y == board_max.y:
		_show_victory(false)
		return true

	return false

func _show_victory(player_red_won: bool) -> void:
	game_over = true
	Menu.visible = true
	back.visible = true
	get_tree().paused = false
	pause_menu.visible = false

	# MODE 1v1
	if GameSettings.game_mode == GameSettings.Mode.MULTI:

		var winner_text := ""

		if player_red_won:
			winner_text = "Victoire du " + player2_name
		else:
			winner_text = "Victoire du " + player1_name

		victory_label.text = winner_text
		victory_panel.visible = true
		victory_label.visible = true
		return


	# MODE CONTRE IA
	if player_red_won:
		victory_panel.visible = true
		victory_label.visible = true
	else:
		defeat_panel.visible = true
		defeat_label.visible = true



func request_player_move(dir: Vector2i) -> void:
	if game_over:
		return
	if current_turn != Turn.PLAYER:
		return

	var t: Vector2i = player_cell + dir

	if _can_move(t):
		player_cell = t
		_update_positions()

		var idx: Vector2i = _index(player_cell)
		if costs[idx.y][idx.x] > 1:
			player_stunned = true

		_end_player_turn()

func request_player_place_wall(cell: Vector2i) -> void:
	if game_over:
		return
	if current_turn != Turn.PLAYER:
		return

	if _set_blocked(cell, true):
		_update_positions()
		_end_player_turn()
		
func request_ai_move(dir: Vector2i) -> void:
	if game_over: 
		return
	if current_turn != Turn.AI:
		return

	var t: Vector2i = ai_cell + dir
	if _can_move(t):
		ai_cell = t
		_update_positions()

		var idx: Vector2i = _index(ai_cell)
		if costs[idx.y][idx.x] > 1:
			ai_stunned = true
		end_ai_turn()


func request_ai_place_wall(cell: Vector2i) -> void:
	if game_over:
		return
	if current_turn != Turn.AI:
		return

	if _set_blocked(cell, true):
		_update_positions()
		end_ai_turn()

func update_turn_label() -> void:
	turn_label.text = "Tour : " + str(turn_count)

func update_turn_indicator() -> void:
	if current_turn == Turn.PLAYER:
		player_node.set_arrow_active(true)
		ai_node.set_arrow_active(false)
	else:
		player_node.set_arrow_active(false)
		ai_node.set_arrow_active(true)

func _on_debug_button_pressed() -> void:
	debug_enabled = !debug_enabled
	_draw_debug()

func _on_retry_pressed() -> void:
	game_over = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menu/Menu_scene.tscn")
