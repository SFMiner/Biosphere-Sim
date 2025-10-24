## PopulationGraph.gd
##
## Real-time line graph for tracking population trends.
## Displays the past 60 seconds of population data across 200 pixels.
## Graph scrolls leftward after the first minute is filled.
##
## Principles:
## - Visual feedback: Provides historical context for population dynamics
## - Data abstraction: Reduces cognitive load by showing trends at a glance
## - Decoupled: Reads from EcosystemManager, never writes to it
##
## References:
## - Ecosystem Simulation Design Principles Section 3.2.3: Temporal Data Visualization

extends Control

## --- CONFIGURATION ---
@export var manager_path: NodePath  # Path to the EcosystemManager node
@export var graph_width: float = 200.0  # Width in pixels
@export var graph_height: float = 150.0  # Height in pixels
@export var time_window: float = 60.0  # Time window in seconds (1 minute)
@export var update_interval: float = 0.1  # How often to sample data (seconds)
@export var line_thickness: float = 2.0  # Thickness of graph lines

## --- SPECIES TO TRACK ---
## Add/remove species names to customize what gets graphed
@export var tracked_species: Array[String] = [
	"algae",
	"volvox",
	"elodea",
	"daphnia",
	"cyclops",
	"snail",
	"hydra",
	"planarian",
	"bacteria",
	"blackworms"
]

## --- SPECIES COLORS (matches Creature.gd) ---
const SPECIES_COLORS = {
	"algae": Color(0.2, 0.8, 0.3, 1.0),
	"volvox": Color(0.078, 0.545, 0.235, 1.0),
	"elodea": Color(0.136, 0.358, 0.227, 1.0),
	"daphnia": Color(0.7, 0.5, 0.2, 1.0),
	"cyclops": Color(0.8, 0.4, 0.3, 1.0),
	"snail": Color(0.6, 0.6, 0.4, 1.0),
	"planarian": Color(0.897, 0.0, 0.856, 1.0),
	"hydra": Color(0.4, 0.2, 0.6, 1.0),
	"bacteria": Color(0.9, 0.9, 0.3, 1.0),
	"blackworms": Color(0.536, 0.151, 0.266, 1.0)
}

## --- INTERNAL STATE ---
var manager: Node = null
var time_elapsed: float = 0.0
var sample_timer: float = 0.0

## History data structure:
## Dictionary of species_name -> Array of {time: float, value: float}
var history: Dictionary = {}

## Maximum biomass seen (for auto-scaling Y axis)
var max_biomass: float = 100.0
var min_biomass: float = 0.0


## --- LIFECYCLE ---

func _ready() -> void:
	# Set custom minimum size for the control
	custom_minimum_size = Vector2(graph_width, graph_height)
	
	# Get reference to EcosystemManager
	if manager_path:
		manager = get_node(manager_path)
	
	if not is_instance_valid(manager):
		push_error("PopulationGraph: Could not find EcosystemManager at path: %s" % manager_path)
		return
	
	# Initialize history arrays for each tracked species
	for species in tracked_species:
		history[species] = []
	
	print("PopulationGraph: Initialized tracking for %d species" % tracked_species.size())


func _process(delta: float) -> void:
	if not is_instance_valid(manager):
		return
	
	# Only update during simulation phase
	if not GameState.is_simulation_phase():
		return
	
	time_elapsed += delta
	sample_timer += delta
	
	# Sample data at regular intervals
	if sample_timer >= update_interval:
		sample_timer = 0.0
		_sample_data()
	
	# Trigger redraw
	queue_redraw()


## --- DATA SAMPLING ---

func _sample_data() -> void:
	"""Sample current population values and add to history."""
	var current_time = time_elapsed
	
	# Sample each tracked species
	for species in tracked_species:
		var biomass = manager.populations.get(species, 0.0)
		
		# Add data point
		history[species].append({
			"time": current_time,
			"value": biomass
		})
		
		# Update max biomass for auto-scaling
		if biomass > max_biomass:
			max_biomass = biomass
	
	# Remove old data points outside the time window
	_prune_old_data()


func _prune_old_data() -> void:
	"""Remove data points older than the time window."""
	var cutoff_time = time_elapsed - time_window
	
	for species in tracked_species:
		var data_array = history[species]
		
		# Remove old points from the beginning of the array
		while data_array.size() > 0 and data_array[0]["time"] < cutoff_time:
			data_array.pop_front()


## --- DRAWING ---

func _draw() -> void:
	if not is_instance_valid(manager):
		return
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, Vector2(graph_width, graph_height)), Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, Vector2(graph_width, graph_height)), Color(0.3, 0.3, 0.3, 1.0), false, 1.0)
	
	# Draw grid lines
	_draw_grid()
	
	# Draw each species line
	for species in tracked_species:
		_draw_species_line(species)
	
	# Draw legend
	#_draw_legend()


func _draw_grid() -> void:
	"""Draw background grid for visual reference."""
	var grid_color = Color(0.2, 0.2, 0.2, 0.5)
	
	# Horizontal lines (every 25% of height)
	for i in range(1, 4):
		var y = graph_height * i / 4.0
		draw_line(Vector2(0, y), Vector2(graph_width, y), grid_color, 1.0)
	
	# Vertical lines (every 25% of width)
	for i in range(1, 4):
		var x = graph_width * i / 4.0
		draw_line(Vector2(x, 0), Vector2(x, graph_height), grid_color, 1.0)


func _draw_species_line(species: String) -> void:
	"""Draw a line graph for a specific species."""
	var data_array = history.get(species, [])
	
	if data_array.size() < 2:
		return  # Need at least 2 points to draw a line
	
	var color = SPECIES_COLORS.get(species, Color.WHITE)
	var points: PackedVector2Array = []
	
	# Convert data points to screen coordinates
	for data_point in data_array:
		var screen_pos = _data_to_screen(data_point["time"], data_point["value"])
		points.append(screen_pos)
	
	# Draw the polyline
	if points.size() >= 2:
		draw_polyline(points, color, line_thickness, true)


func _data_to_screen(time: float, value: float) -> Vector2:
	"""Convert data coordinates (time, biomass) to screen coordinates."""
	# Calculate relative time within the window
	var window_start = max(0.0, time_elapsed - time_window)
	var relative_time = time - window_start
	
	# X position: map time to graph width (left to right)
	var x = (relative_time / time_window) * graph_width
	
	# Y position: map biomass to graph height (inverted, top to bottom)
	# Use max_biomass for auto-scaling, with a minimum range
	var scale_max = max(max_biomass, 10.0)  # Minimum scale of 10
	var y = graph_height - (value / scale_max) * graph_height
	
	return Vector2(x, y)


func _draw_legend() -> void:
	"""Draw a legend showing which color corresponds to which species."""
	var legend_x = 5.0
	var legend_y = 5.0
	var line_height = 12.0
	
	for i in range(tracked_species.size()):
		var species = tracked_species[i]
		var color = SPECIES_COLORS.get(species, Color.WHITE)
		var y_pos = legend_y + i * line_height
		
		# Draw color indicator (small square)
		draw_rect(Rect2(legend_x, y_pos, 8, 8), color)
		
		# Draw species name
		var label_pos = Vector2(legend_x + 12, y_pos + 8)
		draw_string(ThemeDB.fallback_font, label_pos, species.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


## --- UTILITY FUNCTIONS ---

func clear_history() -> void:
	"""Clear all historical data."""
	for species in tracked_species:
		history[species].clear()
	time_elapsed = 0.0
	max_biomass = 100.0
	print("PopulationGraph: History cleared")


func set_tracked_species(species_list: Array[String]) -> void:
	"""Change which species are being tracked."""
	tracked_species = species_list
	
	# Initialize history for new species
	for species in tracked_species:
		if not history.has(species):
			history[species] = []
	
	print("PopulationGraph: Now tracking %d species" % tracked_species.size())
