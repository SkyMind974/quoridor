extends TextureRect

@export var game_scene: PackedScene

@export var main_panel: TextureRect 
@export var mode_panel: TextureRect 
@export var help_panel: TextureRect



func _ready() -> void:
	mode_panel.visible = false
	help_panel.visible = false


func _on_play_pressed() -> void:
	main_panel.visible = false
	mode_panel.visible = true


func _on_aide_pressed() -> void:
	main_panel.visible = false
	help_panel.visible = true


func _on_quitter_pressed() -> void:
	get_tree().quit()



func _on_btn_retour_pressed() -> void:
	mode_panel.visible = false
	help_panel.visible = false
	main_panel.visible = true

func _on_btn_a_star_pressed() -> void:
	GameSettings.algo_mode = GameSettings.Algo.ASTAR
	_start_game()


func _on_btn_dijkstra_pressed() -> void:
	GameSettings.algo_mode = GameSettings.Algo.DIJKSTRA
	_start_game()


func _start_game() -> void:
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
