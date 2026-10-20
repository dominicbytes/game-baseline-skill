extends BaselineTestCase
## Keyboard reachability and hit areas for every screen.

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]
var original_size: Vector2i


func before_each() -> void:
	super()
	original_size = get_tree().root.size


func after_each() -> void:
	get_tree().root.size = original_size
	BaselineFlow.reset_for_tests()
	await frames(1)


func _screens_to_check() -> Array[Control]:
	var screens: Array[Control] = []
	for factory: Callable in [
		func() -> Control: return BaselinePauseMenu.new(),
		func() -> Control: return BaselineCreditsScreen.new(),
		func() -> Control: return BaselineOptionsMenu.create("audio"),
		func() -> Control: return BaselineOptionsMenu.create("display"),
		func() -> Control: return BaselineOptionsMenu.create("controls"),
		func() -> Control: return BaselineOptionsMenu.create("gameplay"),
	]:
		screens.append(factory.call())
	return screens


func _interactive(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and (control is BaseButton or control is Range) and not (control is ScrollBar):
			found.append(control)
	return found


## Scrolls every ScrollContainer around control so control is on screen, as a
## player would with the wheel or scroll bar. Clipped controls cannot be hovered.
func _scroll_into_view(control: Control) -> void:
	var parent := control.get_parent()
	var scrolled := false
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
			scrolled = true
		parent = parent.get_parent()
	if scrolled:
		await frames(1)


func test_every_interactive_control_is_keyboard_focusable_and_in_the_chain() -> void:
	for screen in _screens_to_check():
		BaselineFlow.push_screen(screen)
		await frames(3)
		var controls := _interactive(screen)
		for control in controls:
			expect_eq(control.focus_mode, Control.FOCUS_ALL, "%s %s focusable" % [screen.get_class(), control.name])
		var visited: Array[Control] = []
		var current := get_viewport().gui_get_focus_owner()
		expect(current != null, "%s has initial focus" % screen.name)
		for i in 200:
			if current == null or current in visited:
				break
			visited.append(current)
			current = current.find_next_valid_focus()
		for control in controls:
			expect(control in visited, "%s reachable by Tab" % control.name)
		BaselineFlow.pop_screen()
		await frames(2)


func test_hover_hits_the_right_button_at_every_size() -> void:
	for size in SIZES:
		get_tree().root.size = size
		await frames(2)
		var visible := get_viewport().get_visible_rect().size
		expect(absf(visible.aspect() - Vector2(size).aspect()) < 0.02, "viewport follows %s (got %s)" % [size, visible])
		for screen in _screens_to_check():
			BaselineFlow.push_screen(screen)
			await frames(3)
			for control in _interactive(screen):
				if not control is BaseButton:
					continue
				await _scroll_into_view(control)
				var motion := InputEventMouseMotion.new()
				motion.position = control.get_global_rect().get_center()
				motion.global_position = motion.position
				get_viewport().push_input(motion, true)
				await frames(1)
				var hovered := get_viewport().gui_get_hovered_control()
				expect(hovered == control or (hovered != null and control.is_ancestor_of(hovered)), "%s \"%s\" hit at %s (hovered %s)" % [screen.get_script().get_global_name(), control.get("text"), size, hovered])
			BaselineFlow.pop_screen()
			await frames(2)
