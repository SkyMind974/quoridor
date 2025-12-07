extends Node2D

@export var board_path: NodePath
@onready var arrow: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer


var board
func set_arrow_active(active: bool) -> void:
	arrow.visible = active
	if active:
		anim.play("Arrow")
	else:
		anim.stop()

func _ready() -> void:
	board = get_node(board_path)

func play_turn() -> void:
	if GameSettings.game_mode == GameSettings.Mode.MULTI:
		return
	if board.game_over:
		return
	var ai_goals: Array[Vector2i] = board._ai_goal_cells()
	var ai_path: Array[Vector2i] = board.compute_path(board.ai_cell, ai_goals, board.debug_enabled)

	var player_goals: Array[Vector2i] = board._player_goal_cells()
	var player_path: Array[Vector2i] = board.compute_path(board.player_cell, player_goals, false)

	var placed_wall: bool = false

	if player_path.size() > 1 and ai_path.size() > 0 and player_path.size() <= ai_path.size() + 1:
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
	
func _unhandled_input(event: InputEvent) -> void:
	if GameSettings.game_mode != GameSettings.Mode.MULTI:
		return
	if board.game_over:
		return
	if board.current_turn != board.Turn.AI:
		return

	# Déplacements flèches
	if event is InputEventKey and event.pressed:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_UP: dir = Vector2i(0, -1)
			KEY_DOWN: dir = Vector2i(0, 1)
			KEY_LEFT: dir = Vector2i(-1, 0)
			KEY_RIGHT: dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			board.request_ai_move(dir)

	# Pose mur → clic gauche
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell :Vector2i= board.world_to_grid(get_global_mouse_position())
		board.request_ai_place_wall(cell)
