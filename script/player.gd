extends Node2D

@export var board_path: NodePath
var board

func _ready():
	board = get_node(board_path)

func _unhandled_input(event):
	if board.game_over: return
	if board.current_turn != board.Turn.PLAYER: return

	if event is InputEventKey and event.pressed:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP: dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN: dir = Vector2i(0, 1)
			KEY_A, KEY_LEFT: dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			board.request_player_move(dir)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = board.world_to_grid(get_global_mouse_position())
		board.request_player_place_wall(cell)
