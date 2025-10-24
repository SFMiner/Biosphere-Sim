## Creature.gd
##
## Simple visual representation of an organism.
## Provides animation and movement for visual interest.
## Color changes based on creature type.

extends Node2D

## --- CREATURE TYPES ---
enum CreatureType {
	ALGAE,
	VOLVOX,
	ELODEA,
	DAPHNIA,
	SNAIL,
	PLANARIAN,
	HYDRA,
	BACTERIA,
	BLACKWORMS,
	CYCLOPS
}

## --- CREATURE TYPE MAPPING ---
const CREATURE_TYPE_NAMES = {
	"algae": CreatureType.ALGAE,
	"volvox": CreatureType.VOLVOX,
	"elodea": CreatureType.ELODEA,
	"daphnia": CreatureType.DAPHNIA,
	"snail": CreatureType.SNAIL,
	"planarian": CreatureType.PLANARIAN,
	"hydra": CreatureType.HYDRA,
	"bacteria": CreatureType.BACTERIA,
	"blackworms": CreatureType.BLACKWORMS,
	"cyclops": CreatureType.CYCLOPS
}

## --- COLOR MAPPING ---
const CREATURE_COLORS = {
	CreatureType.ALGAE: Color(0.2, 0.8, 0.3, 1.0),      # Green
	CreatureType.VOLVOX: Color(0.078, 0.545, 0.235, 1.0),      # Dark Green
	CreatureType.ELODEA: Color(0.136, 0.358, 0.227, 1.0),     # Medium Green (plant)
	CreatureType.DAPHNIA: Color(0.7, 0.5, 0.2, 1.0),    # Brown/tan
	CreatureType.SNAIL: Color(0.6, 0.6, 0.4, 1.0),      # Brownish gray
	CreatureType.PLANARIAN: Color(0.897, 0.0, 0.856, 1.0),  # Dark brown (flatworm)
	CreatureType.HYDRA: Color(0.4, 0.2, 0.6, 1.0),      # Purple/brown
	CreatureType.BACTERIA: Color(0.9, 0.9, 0.3, 1.0),    # Yellow
	CreatureType.BLACKWORMS: Color(0.536, 0.151, 0.266, 1.0),    # Dark Red
	CreatureType.CYCLOPS: Color(0.8, 0.4, 0.3, 1.0)     # Orange-red (predatory copepod)
}

## --- ANIMATION PARAMETERS ---

@export var bob_speed: float = 2.0
@export var bob_distance: float = 5.0
@export var drift_speed: float = 0.5
@export var creature_type: String = "algae"
@onready var label : Label = $Label


## --- INTERNAL STATE ---
var start_position: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0
var color_rect: ColorRect = null


func _ready() -> void:
	start_position = position
	label.text = (creature_type)
	_apply_creature_color()


func _process(delta: float) -> void:
	time_elapsed += delta

	# Simple bobbing animation
	var bob_offset = sin(time_elapsed * bob_speed) * bob_distance
	var drift_offset = cos(time_elapsed * drift_speed * 0.5) * bob_distance * 0.5

	position = start_position + Vector2(drift_offset, bob_offset)


## --- COLOR APPLICATION ---

func _apply_creature_color() -> void:
	"""Apply the appropriate color based on creature type."""
	# Find or create ColorRect child
	color_rect = find_child("ColorRect", false, false) as ColorRect
	if not color_rect:
		# If no ColorRect child exists, create one
		color_rect = ColorRect.new()
		color_rect.offset_left = -4.0
		color_rect.offset_top = -4.0
		color_rect.offset_right = 4.0
		color_rect.offset_bottom = 4.0
		add_child(color_rect)

	# Get the creature type from string
	var creature_enum = CREATURE_TYPE_NAMES.get(creature_type.to_lower(), CreatureType.ALGAE)

	# Apply the corresponding color
	var color = CREATURE_COLORS.get(creature_enum, Color.WHITE)
	color_rect.color = color
