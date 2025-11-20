extends Node2D

const SIZE := 9

@onready var ground: TileMap = $TileMapLayer
@onready var player: Node2D = $Player

var player_cell: Vector2i = Vector2i(4, 8)

func _ready():
	_update_player_pos()

func grid_to_world(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)

func _update_player_pos():
	player.position = grid_to_world(player_cell)

func _unhandled_input(event):
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
			if target.x >= 0 and target.x < SIZE and target.y >= 0 and target.y < SIZE:
				player_cell = target
				_update_player_pos()
