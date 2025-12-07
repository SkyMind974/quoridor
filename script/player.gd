extends Node2D

@export var board_path: NodePath
@onready var board: Node = get_node(board_path)


@onready var arrow: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

func set_arrow_active(active: bool) -> void:
	arrow.visible = active
	if active:
		anim.play("Arrow")
	else:
		anim.stop()

func _ready() -> void:
	board = get_node(board_path)

func _unhandled_input(event: InputEvent) -> void:
	if GameSettings.game_mode == GameSettings.Mode.MULTI and board.current_turn != board.Turn.PLAYER:
		return

	if board.game_over:
		return
	if board.current_turn != board.Turn.PLAYER:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var dir: Vector2i = Vector2i.ZERO
		match event.keycode:
			KEY_Z, KEY_W:
				dir = Vector2i(0, -1)
			KEY_S:
				dir = Vector2i(0, 1)
			KEY_Q, KEY_A:
				dir = Vector2i(-1, 0)
			KEY_D:
				dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			board.request_player_move(dir)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = board.world_to_grid(get_global_mouse_position())
		board.request_player_place_wall(cell)
