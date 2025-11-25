extends TextureRect

@export var main_menu_scene: PackedScene
@export var main_panel: TextureRect
@export var help_panel: TextureRect

func _ready() -> void:
	help_panel.visible = false

func _on_play_pressed() -> void:
	main_panel.visible = false

func _on_aide_pressed() -> void:
	main_panel.visible = false
	help_panel.visible = true

func _on_quitter_pressed() -> void:
	get_tree().quit()

func _on_btn_retour_pressed() -> void:
	help_panel.visible = false
	main_panel.visible = true

func _on_menu_pressed() -> void:
	get_tree().paused = false
	if main_menu_scene != null:
		get_tree().change_scene_to_file("res://Menu/Menu_scene.tscn")
