@tool
extends Control

signal radius_changed
signal mesh_selected(mesh)
signal mode_selected(id)
var gridmap =null: set =_set_gridmap, get =_get_gridmap


@onready var mesh_selector = $VBoxContainer/HBoxContainer2/MeshSelector
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _set_gridmap(new_gridmap: GridMap) -> void:
	mesh_selector.clear()
	mesh_selector.add_item("Remove", GridMap.INVALID_CELL_ITEM)
	gridmap = new_gridmap
	var lib = gridmap.mesh_library
	for i in lib.get_item_list():
		mesh_selector.add_item(lib.get_item_name(i), i)

func _get_gridmap() -> GridMap:
	return gridmap

func _on_line_edit_text_changed(new_text):
	emit_signal("radius_changed",int(new_text))

func _on_mesh_selector_item_selected(index):
	emit_signal("mesh_selected", index - 1)

func _on_options_item_selected(index):
	emit_signal("mode_selected", index)
