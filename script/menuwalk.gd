extends Node2D

@export var mode: String = ""          # "astar" ou "dijkstra"
var board                               # MenuScene
var start_cell: Vector2i
var goal_line: Array[Vector2i]

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


func invalidate_path() -> void:
	path.clear()
	step = 0


func _compute_new_path() -> void:
	path = board.compute_path(cell, goal_line, mode)
	step = 0


func _step_loop() -> void:
	if not running:
		return

	if stunned:
		stunned = false
		await get_tree().create_timer(0.25).timeout
		_step_loop()
		return

	await get_tree().process_frame

	if path.is_empty():
		_compute_new_path()
		if path.is_empty():
			await get_tree().create_timer(0.3).timeout
			if running:
				_step_loop()
			return

	if step >= path.size():
		_compute_new_path()
		if path.is_empty():
			await get_tree().create_timer(0.3).timeout
			if running:
				_step_loop()
			return
		step = 0

	_maybe_place_wall()

	if path.is_empty():
		_compute_new_path()
		if path.is_empty():
			await get_tree().create_timer(0.3).timeout
			if running:
				_step_loop()
			return
		step = 0

	var target: Vector2i = path[step]
	step += 1

	var tween := create_tween()
	tween.tween_property(self, "position", board.to_world(target), 0.25)
	await tween.finished

	cell = target

	var idx: Vector2i = board._index(cell)
	if board.costs[idx.y][idx.x] > 1:
		stunned = true

	if goal_line.has(cell):
		running = false
		board.agent_reached_goal(self)
		return

	_step_loop()


func _maybe_place_wall() -> void:
	if not running:
		return
	if path.size() <= 0:
		return

	var me_is_astar: bool = self == board.astar_agent
	var other_agent: Node2D = board.dijkstra_agent if me_is_astar else board.astar_agent

	var other_start: Vector2i = board._world_to_cell(other_agent.position)
	var other_goals: Array[Vector2i] = board._bottom_line() if me_is_astar else board._top_line()
	var other_mode: String = "dijkstra" if me_is_astar else "astar"

	var other_path: Array[Vector2i] = board.compute_path(other_start, other_goals, other_mode)
	var self_path: Array[Vector2i] = path

	if other_path.size() <= 1 or self_path.size() == 0:
		return

	if other_path.size() > self_path.size() + 1:
		return

	var max_check: int = min(other_path.size(), 5)
	var placed_wall: bool = false

	for i in range(1, max_check):
		var c: Vector2i = other_path[i]
		if c == cell or c == other_start:
			continue
		if board._is_blocked(c):
			continue
		if board._set_blocked(c):
			placed_wall = true
			break

	if placed_wall:
		board.astar_agent.invalidate_path()
		board.dijkstra_agent.invalidate_path()
