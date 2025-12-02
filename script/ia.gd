extends Node2D

@export var board_path: NodePath
var board: Node2D

var ai_stunned: bool = false

func _ready() -> void:
	board = get_node(board_path) as Node2D


func play_turn() -> void:
	if board.game_over:
		return

	# 1) Tour de stun : elle passe son tour et se dé-stun
	if ai_stunned:
		ai_stunned = false
		board.end_ai_turn()
		return

	# 2) Calcul des chemins
	var ai_goals: Array[Vector2i] = board._ai_goal_cells()
	var ai_path: Array[Vector2i] = board.compute_path(board.ai_cell, ai_goals, board.debug_enabled)

	var player_goals: Array[Vector2i] = board._player_goal_cells()
	var player_path: Array[Vector2i] = board.compute_path(board.player_cell, player_goals, false)

	# 3) Tentative de poser un mur
	var placed_wall: bool = false

	if player_path.size() > 1 and ai_path.size() > 0 and player_path.size() <= ai_path.size():
		var max_check: int = min(player_path.size(), 5)
		for i in range(1, max_check):
			var c: Vector2i = player_path[i]
			if c == board.ai_cell or c == board.player_cell:
				continue
			if board._is_blocked(c):
				continue
			if board._set_blocked(c, false):
				placed_wall = true
				break

	if placed_wall:
		board._update_positions()
		board.end_ai_turn()
		return

	# 4) Déplacement normal
	if ai_path.size() > 1:
		board.ai_cell = ai_path[1]

	# 5) Après le déplacement, check si la nouvelle case est une case stun
	var idx: Vector2i = board._index(board.ai_cell)
	if board.costs[idx.y][idx.x] > 1:
		board._show_notification("IA étourdie !")
		ai_stunned = true

	board._update_positions()
	board.end_ai_turn()
