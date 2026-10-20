class_name BaselineTheme
extends RefCounted
## Shared theme: readable base font size and a focus outline that is visible
## on every control (never shown by colour or animation alone).
## Stateless: BaselineFlow builds it once and shares it via get_theme().

const FOCUS_COLOR := Color(1.0, 0.82, 0.2)
const FONT_SIZE := 24


## Builds a new Theme. Use BaselineFlow.get_theme() for the shared one.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = FOCUS_COLOR
	focus.set_corner_radius_all(4)
	focus.set_expand_margin_all(3)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "HSlider", "ScrollContainer"]:
		theme.set_stylebox("focus", type, focus)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(24)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme
