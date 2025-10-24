## UIManager.gd
##
## Bridges ecosystem simulation data to UI elements.
## Translates complex simulation data into clear, actionable feedback for the player.
## Handles both Setup Phase and Simulation Phase UI.
##
## Principles:
## - UI as an abstraction layer: Reduces cognitive load by presenting simplified, normalized data
## - One-way data flow: Only reads from EcosystemManager, never writes to it
## - Phase-aware: Displays different UI based on game state
##
## References:
## - Implementation Plan Section 2.2: HUD and Data Abstraction
## - Implementation Plan Section 3: Player Interaction
## - Game Design Document Section 6: UI / UX

extends CanvasLayer

## --- UI ELEMENT REFERENCES (Simulation Phase) ---
@onready var oxygen_bar: ProgressBar = $VBoxContainer/OxygenBar
@onready var oxygen_label: Label = $VBoxContainer/OxygenLabel
@onready var co2_label: Label = $VBoxContainer/CO2Label
@onready var nutrient_label: Label = $VBoxContainer/NutrientLabel
@onready var soft_detritus_label: Label = $VBoxContainer/SoftDetritusLabel
@onready var toxic_waste_bar: ProgressBar = $VBoxContainer/ToxicWasteBar
@onready var toxic_waste_label: Label = $VBoxContainer/ToxicWasteLabel

## Time control references (will be optional if not in scene)
var play_button: Button
var pause_button: Button
var speed_2x_button: Button
var speed_4x_button: Button
var speed_8x_button: Button
var skip_button: Button
var reset_button: Button

## Environment control references (will be optional if not in scene)
var light_slider: HSlider
var light_label: Label
var temp_slider: HSlider
var temp_label: Label
var time_display_label: Label

## Setup phase UI references (will be optional if not in scene)
var setup_panel: PanelContainer
var organism_buttons: VBoxContainer
var seal_button: Button

## Population tracking UI references
var population_labels: Dictionary = {}

## --- MANAGER REFERENCE ---
var manager: Node = null

## --- NORMALIZED RANGES ---
var oxygen_max: float = 22000.0
var co2_max: float = 1000.0
var nutrient_max: float = 200.0
var toxic_waste_danger_level: float = 50.0  # Per liter of tank volume

## --- TIME SCALE STATE ---
var current_time_scale: float = 1.0

## --- CREATURE COLORS (matches Creature.gd) ---
const CREATURE_COLORS = {
	"algae": Color(0.2, 0.8, 0.3, 1.0),      # Green
	"volvox": Color(0.078, 0.545, 0.235, 1.0),      # Dark Green
	"elodea": Color(0.136, 0.358, 0.227, 1.0),     # Medium Green (plant)
	"daphnia": Color(0.7, 0.5, 0.2, 1.0),    # Brown/tan
	"snail": Color(0.6, 0.6, 0.4, 1.0),      # Brownish gray
	"planarian": Color(0.897, 0.0, 0.856, 1.0),      # Brownish gray
	"hydra": Color(0.4, 0.2, 0.6, 1.0),      # Purple/brown
	"bacteria": Color(0.9, 0.9, 0.3, 1.0),    # Yellow
	"blackworms": Color(0.536, 0.151, 0.266, 1.0),    # Dark Red
	"cyclops": Color(0.8, 0.4, 0.3, 1.0)
}

## --- LIFECYCLE ---

func _ready() -> void:
	# Get reference to the EcosystemManager (it's attached to the parent MainScene node)
	manager = get_parent()

	if not is_instance_valid(manager):
		push_error("UIManager: Could not find parent EcosystemManager")
		return

	print("UIManager: Found EcosystemManager on parent node")

	print("\n========== UIManager Diagnostic ==========")
	_print_scene_structure()
	print("==========================================\n")

	# Initialize UI
	_initialize_ui_ranges()
	_initialize_population_labels()
	_connect_signals()
	_update_phase_visibility()


## --- UI INITIALIZATION ---

func _initialize_ui_ranges() -> void:
	if not is_instance_valid(oxygen_bar):
		return

	# Set reasonable max values for progress bars
	oxygen_bar.max_value = oxygen_max
	toxic_waste_bar.max_value = toxic_waste_danger_level * manager.tank_volume * 2.0

	# Initialize sliders if they exist
	light_slider = _find_node_optional("LightSlider")
	temp_slider = _find_node_optional("TemperatureSlider")

	if light_slider:
		light_slider.min_value = 0.0
		light_slider.max_value = 2.0
		light_slider.step = 0.1
		light_slider.value = manager.light_intensity

	if temp_slider:
		temp_slider.min_value = 15.0
		temp_slider.max_value = 30.0
		temp_slider.step = 0.5
		temp_slider.value = manager.temperature


func _initialize_population_labels() -> void:
	"""Initialize references to population label UI elements."""
	var species_list = ["algae", "volvox", "elodea", "daphnia", "snail", "planarian", "hydra", "bacteria", "blackworms", "cyclops"]
	
	for species in species_list:
		var label_name = species.capitalize() + "Label"
		var label = _find_node_optional(label_name)
		if label:
			population_labels[species] = label
			print("UIManager: Found population label for %s" % species)
		else:
			print("UIManager: Could not find population label for %s" % species)


func _find_node_optional(node_name: String) -> Node:
	"""Find a node optionally - returns null if not found (searches recursively)."""
	var node = find_child(node_name, true, true)
	return node if node else null


func _connect_signals() -> void:
	"""Connect UI signals to handler functions."""
	# Find and connect button references
	play_button = _find_node_optional("PlayButton")
	pause_button = _find_node_optional("PauseButton")
	speed_2x_button = _find_node_optional("Speed2xButton")
	speed_4x_button = _find_node_optional("Speed4xButton")
	speed_8x_button = _find_node_optional("Speed8xButton")
	skip_button = _find_node_optional("SkipButton")
	reset_button = _find_node_optional("ResetButton")

	time_display_label = _find_node_optional("TimeDisplayLabel")
	if time_display_label:
		print("UIManager: Found TimeDisplayLabel")

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		play_button.process_mode = PROCESS_MODE_ALWAYS
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		pause_button.process_mode = PROCESS_MODE_ALWAYS
	if speed_2x_button:
		speed_2x_button.pressed.connect(_on_speed_2x_pressed)
		speed_2x_button.process_mode = PROCESS_MODE_ALWAYS
	if speed_4x_button:
		speed_4x_button.pressed.connect(_on_speed_4x_pressed)
		speed_4x_button.process_mode = PROCESS_MODE_ALWAYS
	if speed_8x_button:
		speed_8x_button.pressed.connect(_on_speed_8x_pressed)
		speed_8x_button.process_mode = PROCESS_MODE_ALWAYS
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		skip_button.process_mode = PROCESS_MODE_ALWAYS
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		reset_button.process_mode = PROCESS_MODE_ALWAYS

	# Connect environment controls
	light_slider = _find_node_optional("LightSlider") if not light_slider else light_slider
	temp_slider = _find_node_optional("TemperatureSlider") if not temp_slider else temp_slider

	if light_slider:
		light_slider.value_changed.connect(_on_light_changed)
	if temp_slider:
		temp_slider.value_changed.connect(_on_temperature_changed)

	# Connect setup phase controls
	seal_button = _find_node_optional("SealButton")
	if seal_button:
		seal_button.pressed.connect(_on_seal_pressed)
		print("UIManager: Found SealButton")
	else:
		print("UIManager: Could not find SealButton")

	setup_panel = _find_node_optional("SetupPanel")
	if setup_panel:
		print("UIManager: Found SetupPanel")
		organism_buttons = setup_panel.find_child("OrganismButtons", true, false)
		if organism_buttons:
			print("UIManager: Found OrganismButtons in SetupPanel")
		else:
			print("UIManager: Could not find OrganismButtons in SetupPanel")
			# Try alternative search
			organism_buttons = get_tree().get_root().find_child("OrganismButtons", true, false)
			if organism_buttons:
				print("UIManager: Found OrganismButtons via tree search")
	else:
		print("UIManager: Could not find SetupPanel")


func _create_organism_buttons() -> void:
	"""Create +/- buttons for each organism in setup phase."""
	print("UIManager: _create_organism_buttons called, organism_buttons is: ", organism_buttons)

	if not organism_buttons:
		print("UIManager: ERROR - organism_buttons is null, cannot create buttons")
		return

	print("UIManager: Creating organism buttons...")

	# Clear existing buttons
	for child in organism_buttons.get_children():
		child.queue_free()

	_update_time_display()

	# Create buttons for each species
	var species_list = ["algae", "volvox", "elodea", "daphnia", "snail", "planarian", "hydra", "bacteria", "blackworms", "cyclops"]

	for species in species_list:
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 40)
		hbox.layout_mode = 2

		# Species label with color coding
		var label = Label.new()
		label.text = species.capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.layout_mode = 2
		# Apply color based on creature type
		var color = CREATURE_COLORS.get(species, Color.WHITE)
		label.add_theme_color_override("font_color", color)
		hbox.add_child(label)

		# Add button
		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(40, 0)
		add_btn.layout_mode = 2
		add_btn.pressed.connect(func(): manager.add_organism(species))
		hbox.add_child(add_btn)

		# Remove button
		var remove_btn = Button.new()
		remove_btn.text = "-"
		remove_btn.custom_minimum_size = Vector2(40, 0)
		remove_btn.layout_mode = 2
		remove_btn.pressed.connect(func(): manager.remove_organism(species))
		hbox.add_child(remove_btn)

		organism_buttons.add_child(hbox)
		print("UIManager: Created buttons for %s" % species)


## --- UPDATE LOOP ---

func _process(delta: float) -> void:
	if not is_instance_valid(manager):
		return

	# Update based on current phase
	if GameState.is_setup_phase():
		_update_setup_display()
	else:
		_update_simulation_display()


func _update_time_display() -> void:
	"""Update the elapsed time display."""
	if not is_instance_valid(time_display_label) or not is_instance_valid(manager):
		return
	
	# Get formatted time from manager
	var time_str = manager.get_elapsed_time_formatted()
	var days = manager.get_elapsed_days()
	
	# Display format: "Elapsed: HH:MM:SS (X.X days)"
	time_display_label.text = "Elapsed: %s (%.1f days)" % [time_str, days]

func _update_setup_display() -> void:
	"""Update UI during setup phase."""
	if is_instance_valid(oxygen_label):
		oxygen_label.text = "Oxygen: %.0f" % manager.oxygen
	if is_instance_valid(nutrient_label):
		nutrient_label.text = "Nutrients: %.0f" % manager.nutrient_pool
	
	# Update population displays in setup phase
	_update_population_displays()


func _update_simulation_display() -> void:
	"""Update UI during simulation phase."""
	_update_resource_displays()
	_update_toxicity_indicator()
	_update_environment_labels()
	_update_population_displays()
	_update_time_display()

## --- RESOURCE DISPLAY UPDATE ---

func _update_resource_displays() -> void:
	# Oxygen - Primary indicator with progress bar
	if is_instance_valid(oxygen_bar):
		oxygen_bar.value = manager.oxygen
	if is_instance_valid(oxygen_label):
		oxygen_label.text = "Oxygen: %.0f" % manager.oxygen

	# CO2 - Secondary indicator
	if is_instance_valid(co2_label):
		co2_label.text = "CO2: %.0f" % manager.co2

	# Nutrients - Secondary indicator
	if is_instance_valid(nutrient_label):
		nutrient_label.text = "Nutrients: %.0f" % manager.nutrient_pool

	# Soft Detritus - Secondary indicator
	if is_instance_valid(soft_detritus_label):
		soft_detritus_label.text = "Soft Detritus: %.0f" % manager.soft_detritus


## --- POPULATION DISPLAY UPDATE ---

func _update_population_displays() -> void:
	"""Update all population labels with current biomass values."""
	for species in population_labels.keys():
		var label = population_labels[species]
		if is_instance_valid(label):
			var biomass = manager.populations.get(species, 0.0)
			label.text = "%s: %.1f" % [species.capitalize(), biomass]
			
			# Apply color coding to the label
			var color = CREATURE_COLORS.get(species, Color.WHITE)
			label.add_theme_color_override("font_color", color)


## --- TOXICITY INDICATOR ---

func _update_toxicity_indicator() -> void:
	if not is_instance_valid(toxic_waste_bar):
		return

	# Normalize toxic waste based on tank volume
	var normalized_toxicity = manager.toxic_waste / (manager.tank_volume * toxic_waste_danger_level)

	# Clamp to 0-1 for visual representation, but allow overshoot to show critical state
	var display_value = min(normalized_toxicity * 100.0, toxic_waste_bar.max_value)
	toxic_waste_bar.value = display_value

	# Update label
	if is_instance_valid(toxic_waste_label):
		var quality_text = "Critical"
		if normalized_toxicity < 0.5:
			quality_text = "Good"
		elif normalized_toxicity < 1.0:
			quality_text = "Fair"
		else:
			quality_text = "Critical"

		toxic_waste_label.text = "Water Quality: %s (%.1f%%)" % [quality_text, normalized_toxicity * 100.0]


func _update_environment_labels() -> void:
	"""Update light and temperature labels."""
	light_label = light_label if light_label else _find_node_optional("LightLabel")
	temp_label = temp_label if temp_label else _find_node_optional("TemperatureLabel")

	if is_instance_valid(light_label):
		light_label.text = "Light: %.1fx" % manager.light_intensity
	if is_instance_valid(temp_label):
		temp_label.text = "Temp: %.1f°C" % manager.temperature


## --- SIGNAL HANDLERS: TIME CONTROLS ---

func _on_play_pressed() -> void:
	"""Resume simulation at normal speed."""
	print("Play button pressed")
	Engine.time_scale = 1.0
	current_time_scale = 1.0
	print("Play - Time scale: 1.0x")


func _on_pause_pressed() -> void:
	"""Pause simulation."""
	print("Pause button pressed")
	Engine.time_scale = 0.0
	current_time_scale = 0.0
	print("Pause - Time scale: 0.0x")


func _on_speed_2x_pressed() -> void:
	"""Run simulation at 2x speed."""
	Engine.time_scale = 2.0
	current_time_scale = 2.0
	print("2x Speed - Time scale: 2.0x")


func _on_speed_4x_pressed() -> void:
	"""Run simulation at 4x speed."""
	Engine.time_scale = 4.0
	current_time_scale = 4.0
	print("4x Speed - Time scale: 4.0x")


func _on_speed_8x_pressed() -> void:
	"""Run simulation at 8x speed."""
	Engine.time_scale = 8.0
	current_time_scale = 8.0
	print("8x Speed - Time scale: 8.0x")


func _on_skip_pressed() -> void:
	"""Skip ahead by running simulation at maximum speed for a fixed time."""
	print("Skip ahead - simulating 1 week of gameplay")
	_skip_ahead_async(3600.0)  # Skip 1 hour (60 minutes * 60 seconds)

func _on_reset_pressed() -> void:
	"""Reset the jar."""
	print("Resettingthe jar")
	var main = get_tree().get_nodes_in_group("main")[0]
	main.reset_jar()  # Reset the jar
	

func _skip_ahead_async(duration: float) -> void:
	"""Simulate ahead in time without rendering."""
	var old_time_scale = Engine.time_scale
	Engine.time_scale = 1.0  # Reset to normal for accurate stepping
	var elapsed: float = 0.0

	while elapsed < duration:
		manager.advance_simulation(0.016)  # Fixed 60 FPS step
		elapsed += 0.016

	Engine.time_scale = old_time_scale  # Restore previous time scale
	print("Skip complete! Simulated %.0f seconds" % duration)


## --- SIGNAL HANDLERS: ENVIRONMENT CONTROLS ---

func _on_light_changed(value: float) -> void:
	"""Handle light intensity slider change."""
	if is_instance_valid(manager):
		manager.light_intensity = value


func _on_temperature_changed(value: float) -> void:
	"""Handle temperature slider change."""
	if is_instance_valid(manager):
		manager.temperature = value


## --- SIGNAL HANDLERS: SETUP PHASE ---

func _on_seal_pressed() -> void:
	"""Seal the jar and enter simulation phase."""
	setup_panel.visible = false
	if GameState.is_setup_phase():
		manager.seal_jar()
		_update_phase_visibility()
		print("Jar sealed - entering simulation phase")


## --- PHASE MANAGEMENT ---

func _update_phase_visibility() -> void:
	"""Show/hide UI elements based on current game phase."""
	if GameState.is_setup_phase():
		# Setup phase: show organism buttons, hide time controls
		if setup_panel:
			setup_panel.show()
		_show_time_controls(false)
		_show_environment_controls(false)
		# Create organism buttons
		_create_organism_buttons()
	else:
		# Simulation phase: hide organism buttons, show time/environment controls
		if setup_panel:
			setup_panel.hide()
		_show_time_controls(true)
		_show_environment_controls(true)


func _show_time_controls(visible: bool) -> void:
	"""Show or hide time control buttons."""
	for btn in [play_button, pause_button, speed_2x_button, speed_4x_button, speed_8x_button, skip_button]:
		if is_instance_valid(btn):
			btn.visible = visible


func _show_environment_controls(visible: bool) -> void:
	"""Show or hide environment control sliders."""
	if is_instance_valid(light_slider):
		light_slider.visible = visible
	if light_label:
		light_label = light_label if light_label else _find_node_optional("LightLabel")
		if is_instance_valid(light_label):
			light_label.visible = visible
	if is_instance_valid(temp_slider):
		temp_slider.visible = visible
	if temp_label:
		temp_label = temp_label if temp_label else _find_node_optional("TemperatureLabel")
		if is_instance_valid(temp_label):
			temp_label.visible = visible


## --- HELPER FUNCTIONS ---

func get_species_display_name(species_name: String) -> String:
	"""Convert internal species name to display-friendly name."""
	return species_name.capitalize()


func get_resource_status_color(resource_name: String, value: float) -> Color:
	"""Return a color indicating the status of a resource."""
	match resource_name:
		"oxygen":
			if value < 5000:
				return Color.RED
			elif value < 10000:
				return Color.YELLOW
			else:
				return Color.GREEN
		"toxic_waste":
			var normalized = value / (manager.tank_volume * toxic_waste_danger_level)
			if normalized < 0.5:
				return Color.GREEN
			elif normalized < 1.0:
				return Color.YELLOW
			else:
				return Color.RED
		_:
			return Color.WHITE


## --- DIAGNOSTIC FUNCTIONS ---

func _print_scene_structure() -> void:
	"""Print the scene structure to help diagnose UI issues."""
	print("UI CanvasLayer children:")
	for child in get_children():
		print("  - %s (%s)" % [child.name, child.get_class()])
		if child.name == "SetupPanel" or child.name == "PopulationPanel":
			_print_children_recursive(child, "    ")

func _print_children_recursive(node: Node, indent: String) -> void:
	"""Recursively print node children."""
	for child in node.get_children():
		print("%s- %s (%s)" % [indent, child.name, child.get_class()])
		_print_children_recursive(child, indent + "  ")
