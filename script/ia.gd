extends Node2D

@export var board_path: NodePath
var board

func _ready():
	board = get_node(board_path)

func play_turn():
	if board.game_over:
		return

	var ai_goals = board._ai_goal_cells()
	var ai_path = board.compute_path(board.ai_cell, ai_goals, board.debug_enabled)

	var player_goals = board._player_goal_cells()
	var player_path = board.compute_path(board.player_cell, player_goals, false)

	var placed_wall := false

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

	if ai_path.size() > 1:
		board.ai_cell = ai_path[1]

	board._update_positions()
	board.end_ai_turn()
