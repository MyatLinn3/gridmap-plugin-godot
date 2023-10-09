@tool
extends EditorPlugin

enum Mode {
	NONE,
	RADIUS,
	BUCKET
}


const tool = preload("res://addons/gridmapadditions/grid_tools.tscn")

var toolbar = null

var current_gridmap = null
var r =  1
var mesh = null
var mouse_down = false
var can_perform_action = true
var action_timer = null

var mode = null

var undo_redo = null
func _enter_tree():
	undo_redo = get_undo_redo()
	toolbar = tool.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL,toolbar)
	toolbar.radius_changed.connect(getRadiusChanged)
	toolbar.mesh_selected.connect(getMeshChanged)
	toolbar.mode_selected.connect(getModeChanged)
	
	action_timer = Timer.new()
	action_timer.wait_time = 0.2
	action_timer.one_shot = false
	add_child(action_timer)
	action_timer.timeout.connect(reset_action)
	action_timer.start()

func reset_action():
	can_perform_action = true

func getMeshChanged(m):
	mesh = m

func getRadiusChanged(radius):
	print(radius)
	r = radius

func getModeChanged(m):
	match m:
		0:mode = Mode.NONE
		1:mode= Mode.RADIUS
		2:mode = Mode.BUCKET

func _exit_tree():
	remove_control_from_docks(toolbar)
	toolbar.free()
	action_timer.free()


func _handles(object):
	print("hee")
	return object is GridMap

func _edit(object):
	print("Editing: ", object)
	current_gridmap = object
	toolbar.gridmap = object

func _forward_3d_gui_input(viewport_camera, event):
	var captured_event = false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			# @todo: commit action
			captured_event = true
#			var hit_pos = get_mouse_projection(current_gridmap, viewport_camera, event.position)
#			var add_pos = null
#			var intersection = null
#			print(hit_pos)
#			if hit_pos.has("position"):
#				add_pos = hit_pos["position"]
#				add_pos.y += 1
#				intersection = hit_pos["position"]
#			if hit_pos.has("moment"):
#				add_pos = hit_pos["moment"]
#			_do_brush(add_pos, intersection)
			mouse_down = true
			captured_event = do_brush(viewport_camera, event)

		if event.button_index == MOUSE_BUTTON_LEFT and !event.is_pressed():
			mouse_down = false
			captured_event = do_brush(viewport_camera, event)

	if !can_perform_action:
		return mouse_down

	if event is InputEventMouseMotion:
		captured_event = do_brush(viewport_camera, event)

	return captured_event
	
func do_brush(camera, event) -> bool:
	var action_captured = false

	if current_gridmap == null:
		print("must set gridmap with Use Selected button")
		return action_captured

	if event is InputEventMouseMotion:
		if !mouse_down:
			return action_captured
	
		var hit_pos = get_mouse_projection(current_gridmap, camera, event.position)

		var add_pos = null
		var intersection = null
		print(hit_pos)
		if hit_pos.has("position"):
			add_pos = hit_pos["position"]
			add_pos.y += 1
			intersection = hit_pos["position"]
		if hit_pos.has("moment"):
			add_pos = hit_pos["moment"]
			
		if hit_pos == null:
			action_captured = true
		else:
			_do_brush(add_pos, intersection)
			can_perform_action = false
			action_captured = true


	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			push_undo_stack(current_gridmap)
			undo_redo.create_action("Paint GridMap")
			undo_redo.add_redo_method(self,"undo_paint_gridmap")
			mouse_down = true
			action_captured = true
		if event.button_index == MOUSE_BUTTON_LEFT and !event.is_pressed():
			mouse_down = false
			action_captured = true
			undo_redo.commit_action()

	return action_captured

func _do_brush(position,intersection):
	if mode == Mode.BUCKET:
#		gm_func_paint_bucket(current_gridmap, position, mesh)
		func_paint_bucket(current_gridmap,Vector3(position)+Vector3(1,0,0),0)
		func_paint_bucket(current_gridmap,Vector3(position)-Vector3(1,0,0),0)
		func_paint_bucket(current_gridmap,Vector3(position)+Vector3(0,0,1),0)
		func_paint_bucket(current_gridmap,Vector3(position)-Vector3(0,0,1),0)
#		return
	else:
		var idxs = get_circle(current_gridmap,position,r)
		print(idxs)
		print(mesh)
		for i in idxs:
			current_gridmap.set_cell_item(Vector3(i.x, i.y, i.z), mesh, 0)
#	undo_redo.create_action("Paint GridMap")
#	undo_redo.add_redo_method(self,"undo_paint_gridmap")
#	undo_redo.commit_action()

func undo_paint_gridmap():
	var momento = pop_undo_stack(current_gridmap)
	restore_momento(current_gridmap, momento)

func create_momento(gm: GridMap) -> Array:
	var momento = []
	for i in gm.get_used_cells():
		momento.append({
			"position": i,
			"mesh": gm.get_cell_item(Vector3(i.x, i.y, i.z)),
			"orientation": gm.get_cell_item_orientation(Vector3(i.x, i.y, i.z)),
		})
	return momento

func restore_momento(gm: GridMap, momento: Array) -> void:
	gm.clear()
	for i in momento:
		var pos = i["position"]
		var mesh = i["mesh"]
		var orientation = i["orientation"]
		gm.set_cell_item(Vector3(pos.x, pos.y, pos.z), mesh, 0)

func push_undo_stack(gm: GridMap) -> void:
	var momento = create_momento(gm)
	if !gm.has_meta('redo_stack'):
		gm.set_meta('redo_stack', [])
	var undo_stack = gm.get_meta('redo_stack')
	undo_stack.push_back(momento)
	if undo_stack.size() > 20:
		undo_stack.pop_front()

func pop_undo_stack(gm: GridMap) -> Dictionary:
	if !gm.has_meta('redo_stack'):
		gm.set_meta('redo_stack', [])
	var undo_stack = gm.get_meta('redo_stack')
	var momento = undo_stack.back()
	undo_stack.pop_back()
	return momento

func get_circle(gm: GridMap, origin: Vector3, radius: int) -> Array:
	var out = []
	for i in range(-1 * radius, 1 + radius):
		for j in range(-1 * radius, 1 + radius):
			var pos = origin + Vector3(i, 0, j)
			if (origin - pos).length() < radius:
				out.append(pos)
	return out


func get_mouse_projection(gm: GridMap, camera, mouse) -> Dictionary:
	var origin = camera.project_ray_origin(mouse)
	var dir = camera.project_ray_normal(mouse)
	return raycast(gm,origin,dir)

func intersects(gm: GridMap, position: Vector3) -> bool:
	var map_pos : Vector3 = gm.local_to_map(position)
	var cell : int = gm.get_cell_item(map_pos)
	if cell != gm.INVALID_CELL_ITEM:
		return true
	return false

func raycast(gm: GridMap, origin: Vector3, dir: Vector3) -> Dictionary:
	if intersects(gm, origin):
		return {
			"position": gm.local_to_map(origin)
		}
	
	var moment = origin

	var pos = origin
	var unit = 0.2
	var d = 0.0
	var max_distance = 8000.0
	while d < max_distance:
		pos += dir * unit
		if intersects(gm, pos):
			return {
				"position": gm.local_to_map(pos),
				"moment": gm.local_to_map(pos),
			}
		d += unit
		moment = pos
	return {}

func func_paint_bucket(gm: GridMap, idx: Vector3, count: int) -> void:
	var cell = gm.get_cell_item(idx)
	if cell == mesh:
		return
	if cell != GridMap.INVALID_CELL_ITEM:
		return
	if count >= 500:
		return
	gm.set_cell_item(idx,mesh,0)
	count += 1
	func_paint_bucket(gm,idx+Vector3(1,0,0),mesh)
	func_paint_bucket(gm,idx-Vector3(1,0,0),mesh)
	func_paint_bucket(gm,idx+Vector3(0,0,1),mesh)
	func_paint_bucket(gm,idx-Vector3(0,0,1),mesh)

func neighbors_of_type(out: Dictionary, gm: GridMap, idx: Vector3, mesh: int) -> Dictionary:
	for i in neighbors(gm, idx):
		var cell : int = gm.get_cell_item(Vector3(i.x, i.y, i.z))
		if cell == mesh:
			if !out.has(i):
				out[i] = true
	return out

func neighbors(gm: GridMap, idx: Vector3) -> Array:
	var out = []
	for i in range(idx.x - 1, idx.x + 2):
		for j in range(idx.z - 1, idx.z + 2):
			out.append(Vector3(i, 0, j))
	return out


#func gm_push_undo_stack(gm: GridMap) -> void:
#	var momento = gm_create_momento(gm)
#	if !gm.has_meta('undo_stack'):
#		gm.set_meta('undo_stack', [])
#	var undo_stack = gm.get_meta('undo_stack')
#	undo_stack.push_back(momento)
#	if undo_stack.size() > UNDO_STACK_MAX_SIZE:
#		undo_stack.pop_front()
