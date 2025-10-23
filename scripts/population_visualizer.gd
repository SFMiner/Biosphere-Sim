## PopulationVisualizer.gd
##
## Manages the visual representation of a single species population.
## This script reads population data from the EcosystemManager but never writes to it.
## Spawns and despawns visual creatures based on population density.
##
## Principles:
## - Decoupled from simulation: Only reads data, doesn't affect simulation logic
## - Independent visual updates: Uses _process for smooth animations independent of physics ticks
##
## References:
## - Implementation Plan Section 2.1: Decoupled Visuals

extends Node2D

## --- CONFIGURATION ---
@export var manager_path: NodePath  # Path to the EcosystemManager node
@export var species_name: String    # Name of the species this visualizer represents
@export var creature_scene: PackedScene  # Scene to spawn for each creature unit
@export var density_per_sprite: float = 5.0  # How much biomass per visible creature

## Container bounds for positioning creatures
@export var container_width: float = 1024.0
@export var container_height: float = 768.0

## --- INTERNAL REFERENCES ---
var manager: Node = null
var random: RandomNumberGenerator = RandomNumberGenerator.new()


## --- LIFECYCLE ---

func _ready() -> void:
	# Get reference to the EcosystemManager
	if manager_path:
		manager = get_node(manager_path)

	random.randomize()


## --- VISUAL UPDATE LOOP ---
## Runs every frame to update creature count based on population

func _process(delta: float) -> void:
	if not is_instance_valid(manager):
		return

	# Get current population for this species
	var density = manager.populations.get(species_name, 0.0)
	var target_count = int(density / density_per_sprite)

	var current_count = get_child_count()

	# Spawn new creatures if population increased
	if current_count < target_count:
		for i in range(target_count - current_count):
			_spawn_creature()

	# Despawn creatures if population decreased
	elif current_count > target_count:
		for i in range(current_count - target_count):
			if get_child_count() > 0:
				get_child(0).queue_free()


## --- CREATURE SPAWNING ---

func _spawn_creature() -> void:
	if not creature_scene:
		return

	var creature = creature_scene.instantiate()

	# Set the creature type so it displays with the correct color
	creature.creature_type = species_name

	# Position randomly within container bounds
	var random_x = random.randf_range(0.0, container_width)
	var random_y = random.randf_range(0.0, container_height)
	creature.position = Vector2(random_x, random_y)

	add_child(creature)
