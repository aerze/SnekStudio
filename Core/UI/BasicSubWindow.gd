@tool
extends Control
class_name BasicSubWindow

var is_mouse_in_window = false
var is_move_dragging = false
var is_mouse_in_border = false

var is_size_dragging = false
var size_dragging_vertical_edge = 0 # -1, 0, 1 for top, middle, bottom
var size_dragging_horizontal_edge = 0 # -1, 0, 1 for left, middle, right

# Serializable dimensions
var embed_window_pos: Vector2 = Vector2(0, 0)
var embed_window_size: Vector2 = Vector2(0, 0)

# Position in parent.
var _drag_start_position = position
var _drag_start_size = size

# Drag position relative to start of drag.
var _drag_current_position = Vector2(0, 0)

@export var close_button_visible : bool = true
@export var label_text : String = "Window"

signal close_requested

func _ready():
	_on_resized()
	if not close_button_visible:
		_set_close_button_visible(close_button_visible)
	$WindowTitlePanel/WindowTitle.text = label_text

# Used to optionally add this subwindow to the list of
# savable subwindows in SnekStudio_Main. Dimensions
# and other state will be saved and restored.
func register_serializable_subwindow():
	_get_app_root().subwindows.push_back(self)

func _process(_delta):
	
	# FIXME: Is there a better way to do these than polling every frame?
	var child = _find_child()
	if child:
		var child_min_size = child.get_combined_minimum_size()
		if child_min_size.x > size.x:
			size.x = child_min_size.x
		if child_min_size.y > size.y:
			size.y = child_min_size.y

	if label_text != $WindowTitlePanel/WindowTitle.text:
		$WindowTitlePanel/WindowTitle.text = label_text

	if close_button_visible != $WindowTitlePanel/CloseButton.visible:
		_set_close_button_visible(close_button_visible)
		
func _find_child():
	for child in get_children():
		if child != $WindowTitlePanel and child != $WindowBorder:
			return child
	return null

func _on_resized() -> void:
	var current_title_size = $WindowTitlePanel.size
	$WindowTitlePanel.size = Vector2(size[0], current_title_size[1])
	$WindowTitlePanel/WindowTitle.size.x = \
		$WindowTitlePanel.size.x - \
		2 * $WindowTitlePanel/WindowTitle.position.x

	if $WindowTitlePanel/CloseButton.visible:
		$WindowTitlePanel/WindowTitle.size.x = \
			$WindowTitlePanel/WindowTitle.size.x - \
			$WindowTitlePanel/CloseButton.size.x

	var child = _find_child()
	if child:
		child.set_size(size)
		child.position = Vector2(0.0, 0.0)

func _get_minimum_size():
	var expected_minimum_size = Vector2(64, 64)
	var child = _find_child()
	var child_minimum_size = expected_minimum_size
	if child:
		child_minimum_size = child.get_combined_minimum_size()
	
	if expected_minimum_size.x < child_minimum_size.x:
		expected_minimum_size.x = child_minimum_size.x
	if expected_minimum_size.y < child_minimum_size.y:
		expected_minimum_size.y = child_minimum_size.y

	return expected_minimum_size

func _set_close_button_visible(_is_visible):
	$WindowTitlePanel/CloseButton.visible = _is_visible
	_on_resized()

# Clamps the window (at least the title bar) to the screen to make sure we don't
# accidentally drag something off-screen.
func _ensure_window_visibility():
	var minimum_visible_border = 16
	
	var min_position_x = -size.x + minimum_visible_border
	var max_position_x = get_parent().size.x - minimum_visible_border

	var min_position_y = $WindowTitlePanel.size.y
	var max_position_y = get_parent().size.y
	
	if position.x > max_position_x:
		position.x = max_position_x
	if position.x < min_position_x:
		position.x = min_position_x

	# Correct max (+y = lower) vertical position first, so if the bottom of the
	# window goes off the bottom of the screen, the title bar remains at the
	# top.
	if position.y > max_position_y:
		position.y = max_position_y
	if position.y < min_position_y:
		position.y = min_position_y

func _input(event):
	if event is InputEventMouseMotion:
		if is_move_dragging:
			_drag_current_position += event.relative
			position = _drag_start_position + _drag_current_position
			_ensure_window_visibility()

func _on_mouse_entered():
	is_mouse_in_window = true

func _on_mouse_exited():
	is_mouse_in_window = false

func _on_focus_entered():
	get_parent().move_child(self, get_parent().get_child_count() - 1)

func _on_window_title_panel_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_on_focus_entered()
			grab_focus()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_move_dragging = true
				_drag_start_position = position
				_drag_current_position = Vector2(0, 0)
				print("starting drag")
			else:
				is_move_dragging = false
				print("Stopping drag")

func _on_window_border_mouse_entered():
	is_mouse_in_border = true

func _on_window_border_mouse_exited():
	is_mouse_in_border = false

func _on_window_border_gui_input(event):

	var position_in_windowspace = Vector2(0.0, 0.0)
	if (event is InputEventMouseButton) or (event is InputEventMouseMotion):
		position_in_windowspace = event.position + $WindowBorder.position

	if event is InputEventMouseMotion:
		var potential_dragging_edge_horizontal = 0
		var potential_dragging_edge_vertical = 0
		
		if position_in_windowspace.x < 0:
			potential_dragging_edge_horizontal = -1
		elif position_in_windowspace.x > size.x:
			potential_dragging_edge_horizontal = 1
		else:
			potential_dragging_edge_horizontal = 0
			
		if position_in_windowspace.y < 0:
			potential_dragging_edge_vertical = -1
		elif position_in_windowspace.y > size.y:
			potential_dragging_edge_vertical = 1
		else:
			potential_dragging_edge_vertical = 0

		var cursor_shape = Input.CURSOR_ARROW
		if potential_dragging_edge_horizontal == 0 and potential_dragging_edge_vertical == 0:
			pass
		elif potential_dragging_edge_horizontal != 0 and potential_dragging_edge_vertical == 0:
			cursor_shape = Input.CURSOR_HSIZE
		elif potential_dragging_edge_horizontal == 0 and potential_dragging_edge_vertical != 0:
			cursor_shape = Input.CURSOR_VSIZE
		elif potential_dragging_edge_horizontal == potential_dragging_edge_vertical:
			cursor_shape = Input.CURSOR_FDIAGSIZE
		elif potential_dragging_edge_horizontal != potential_dragging_edge_vertical:
			cursor_shape = Input.CURSOR_BDIAGSIZE
			
		$WindowBorder.mouse_default_cursor_shape = cursor_shape
				


	if event is InputEventMouseButton:
		
		if event.pressed:
			_on_focus_entered()
			grab_focus()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_mouse_in_window:
					is_size_dragging = true
					_drag_start_position = position
					_drag_start_size = size
					_drag_current_position = Vector2(0.0, 0.0)
					
					if position_in_windowspace.x < 0:
						size_dragging_horizontal_edge = -1
					elif position_in_windowspace.x > size.x:
						size_dragging_horizontal_edge = 1
					else:
						size_dragging_horizontal_edge = 0
						
					if position_in_windowspace.y < 0:
						size_dragging_vertical_edge = -1
					elif position_in_windowspace.y > size.y:
						size_dragging_vertical_edge = 1
					else:
						size_dragging_vertical_edge = 0
			else:
				if is_size_dragging:
					_ensure_window_visibility()
					is_size_dragging = false

	if event is InputEventMouseMotion:
		if is_size_dragging:
			_drag_current_position += event.relative
			
			var output_size = size
			var output_position = position
			
			if size_dragging_horizontal_edge > 0:
				output_size.x = _drag_start_size.x + _drag_current_position.x
			if size_dragging_vertical_edge > 0:
				output_size.y = _drag_start_size.y + _drag_current_position.y

			if size_dragging_horizontal_edge < 0:
				output_size.x = _drag_start_size.x - _drag_current_position.x
				output_position.x = _drag_start_position.x + _drag_current_position.x
			if size_dragging_vertical_edge < 0:
				output_size.y = _drag_start_size.y - _drag_current_position.y
				output_position.y = _drag_start_position.y + _drag_current_position.y

			var min_size = get_combined_minimum_size()

			if output_size.x < min_size.x:
				if size_dragging_horizontal_edge < 0:
					output_position.x -= min_size.x - output_size.x
				output_size.x = min_size.x

			if output_size.y < min_size.y:
				if size_dragging_vertical_edge < 0:
					output_position.y -= min_size.y - output_size.y
				output_size.y = min_size.y
			
			size = output_size
			position = output_position

func _on_close_button_pressed():
	if len(close_requested.get_connections()):
		emit_signal("close_requested")
	else:
		close_window()

func close_window():
	_save_current_window_state()
	hide()

func show_window():
	visible = true
	_on_resized()
	grab_focus()
	_on_focus_entered()

func _get_app_root():
	return find_parent("SnekStudio_Main")

# -----------------------------------------------------------------------------
# Virtual functions

#region Virtual functions

func serialize_window() -> Dictionary:
	return {}

func deserialize_window(dict: Dictionary) -> void:
	pass

#endregion

# -----------------------------------------------------------------------------
# Window serialization

#region Window state serialization

# Internal serialization called by SnekStudio_Main when saving subwindows
func _serialize_window() -> Dictionary:
	_save_current_window_state()

	var subwindow: Dictionary = {
		"embed_window_pos": [embed_window_pos.x, embed_window_pos.y],
		"embed_window_size": [embed_window_size.x, embed_window_size.y]
	}

	var window_settings: Dictionary = serialize_window()
	if window_settings.size() != 0:
		subwindow["settings"] = window_settings

	return subwindow

# Internal deserialization called by SnekStudio_Main when loading subwindows
func _deserialize_window(subwindow_dict: Dictionary) -> void:
	embed_window_pos = Vector2(subwindow_dict["embed_window_pos"][0],
							   subwindow_dict["embed_window_pos"][1])
	embed_window_size = Vector2(subwindow_dict["embed_window_size"][0],
								subwindow_dict["embed_window_size"][1])
	_load_window_state()

	var settings = subwindow_dict.get("settings")
	if settings is Dictionary:
		deserialize_window(settings)

#endregion

# -----------------------------------------------------------------------------
# Window state

#region Window state

func _save_current_window_state() -> void:
	embed_window_pos = position
	embed_window_size = size

func _load_window_state() -> void:
	position = embed_window_pos
	size = embed_window_size

#endregion
