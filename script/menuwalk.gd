extends Node2D

@export var mode: String = ""        
var board: Node
var start_cell: Vector2i
var goal_line: Array[Vector2i] = []

var cell: Vector2i
var path: Array[Vector2i] = []
var step: int = 0
var running: bool = false
var stunned: bool = false


func start() -> void:
	running = true
	stunned = false
	cell = start_cell
	position = board.to_world(cell)
	_compute_new_path()
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

	# ------------------------------------------------
	# 1) STUN
	# ------------------------------------------------
	if stunned:
		stunned = false
		await get_tree().create_timer(0.25).timeout
		_step_loop()
		return

	await get_tree().process_frame

	# ------------------------------------------------
	# 2) PATH VIDE
	# ------------------------------------------------
	if path.is_empty():
		_compute_new_path()
		if path.is_empty():
			await get_tree().create_timer(0.3).timeout
			if running:
				_step_loop()
			return

	# ------------------------------------------------
	# 3) FIN DU CHEMIN => recalcul
	# ------------------------------------------------
	if step >= path.size():
		_compute_new_path()
		if path.is_empty():
			await get_tree().create_timer(0.3).timeout
			if running:
				_step_loop()
			return
		step = 0

	# ------------------------------------------------
	# 4) DEPLACEMENT
	# ------------------------------------------------
	var target: Vector2i = path[step]
	step += 1

	var tween := create_tween()
	tween.tween_property(self, "position", board.to_world(target), 0.25)
	await tween.finished

	cell = target

	# ------------------------------------------------
	# 5) CHECK STUN (TYPÉ !)
	# ------------------------------------------------
	var idx: Vector2i = board._index(cell)

	if board.costs[idx.y][idx.x] > 1:
		stunned = true

	# ------------------------------------------------
	# 6) VICTOIRE
	# ------------------------------------------------
	if goal_line.has(cell):
		running = false
		board.agent_reached_goal(self)
		return

	_step_loop()
