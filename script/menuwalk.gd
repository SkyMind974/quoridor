extends Node2D

@export var mode : String = ""          # "astar" ou "dijkstra"
var board                          # MenuScene
var start_cell : Vector2i
var goal_line : Array[Vector2i]

var cell : Vector2i
var path : Array[Vector2i] = []
var step : int = 0
var running: bool = false


func start() -> void:
	running = true
	cell = start_cell
	position = board.to_world(cell)
	path.clear()
	step = 0
	_step_loop()


func stop() -> void:
	running = false


func _compute_new_path() -> void:
	path = board.compute_path(cell, goal_line, mode)
	step = 0


func _step_loop() -> void:
	if not running:
		return

	# petite pause pour éviter une récursion trop agressive
	await get_tree().create_timer(0.01).timeout

	if path.is_empty():
		_compute_new_path()
		await get_tree().create_timer(0.3).timeout
		_step_loop()
		return

	if step >= path.size():
		_compute_new_path()
		await get_tree().create_timer(0.3).timeout
		_step_loop()
		return

	var target: Vector2i = path[step]
	step += 1

	var tween = create_tween()
	tween.tween_property(self, "position", board.to_world(target), 0.25)
	await tween.finished

	cell = target

	# Victoire : on est sur la ligne goal_line
	if goal_line.has(cell):
		running = false
		board.agent_reached_goal(self)
		return

	_step_loop()
