## EcosystemManager.gd
##
## The core simulation engine for Biosphere Jar.
## This script manages all resource pools, species populations, and the simulation logic.
##
## BALANCE FIXES (v2):
## - All rates now consistently use step_delta (time-based, not frame-based)
## - Bacteria waste production reduced to prevent toxic waste explosion
## - Predation rates reduced to allow prey populations to stabilize
## - Decomposition rates adjusted to balance nitrogen cycle
##
## TIME TRACKING (v3):
## - Added proper elapsed time tracking that respects Engine.time_scale
## - Time pauses when time_scale = 0, speeds up with 2x/4x/8x
##
## Principles:
## - Simulation First: All core logic is decoupled from rendering and uses fixed timestep
## - Data-Driven Design: Species rules and parameters are defined in data structures, not hard-coded
##
## References:
## - Game Design Document (GDD) Section 3: Core Mechanics
## - Implementation Plan Section 1: Core Simulation Engine

extends Node

## --- RESOURCE POOLS (GDD 3.1) ---
## These represent the chemical state of the biosphere
@export var oxygen: float = 21000.0
@export var co2: float = 400.0
@export var nutrient_pool: float = 100.0
@export var soft_detritus: float = 50.0
@export var hard_detritus: float = 200.0
@export var toxic_waste: float = 0.0
var pop_visualizer: Script = preload("res://scripts/population_visualizer.gd")  # Scene to spawn for each creature unit
@onready var visual_container: Node2D = $VisualContainer  # How much biomass per visible 
@onready var reset_button: Button = $UI/VBoxContainer/ResetButton# How much biomass per visible 

## --- SPECIES DATA (GDD 3.2) ---
## All species data is stored in flexible Dictionaries for easy modification and expansion

@export var populations: Dictionary = {
	"algae": 100.0,
	"volvox": 50.0,
	"elodea": 50.0,
	"daphnia": 20.0,
	"snail": 5.0,
	"planarian": 25.0,
	"hydra": 5.0,
	"blackworms": 5.0,
	"bacteria": 200.0,  # v3 FIX: Increased from 50.0 (4x more bacteria)
	"cyclops": 15.0
}
## BALANCE FIX: Reduced waste production rates significantly
@export var species_params: Dictionary = {
	"snail": {
		"unit_biomass": 15.0,
		"soft_biomass": 5.0,
		"hard_biomass": 10.0,
		"respiration": 0.008,
		"death": 0.015,
		"waste": 0.008,
		"toxicity_sensitivity": 0.2
	},
	"planarian": {
		"unit_biomass": 3.0,
		"soft_biomass": 2.5,
		"hard_biomass": 0.5,
		"respiration": 0.01,
		"death": 0.018,
		"waste": 0.006,
		"toxicity_sensitivity": 0.25,
		"growth_rate": 0.06  # v3 FIX: Reduced from 0.12 (50% reduction)
	},
	"daphnia": {
		"unit_biomass": 2.0,
		"soft_biomass": 1.5,
		"hard_biomass": 0.5,
		"respiration": 0.012,
		"death": 0.02,
		"waste": 0.006,
		"toxicity_sensitivity": 0.4
	},
	"algae": {
		"unit_biomass": 5.0,
		"soft_biomass": 4.0,
		"hard_biomass": 1.0,
		"respiration": 0.004,
		"death": 0.005,  # v3 FIX: Reduced from 0.008 (more hardy)
		"waste": 0.0,
		"toxicity_sensitivity": 0.1
	},
	"volvox": {
		"unit_biomass": 3.0,
		"soft_biomass": 2.0,
		"hard_biomass": 1.0,
		"respiration": 0.004,
		"death": 0.008,
		"waste": 0.0,
		"toxicity_sensitivity": 0.1
	},
	"elodea": {
		"unit_biomass": 20.0,
		"soft_biomass": 15.0,
		"hard_biomass": 5.0,
		"respiration": 0.003,
		"death": 0.004,  # v3 FIX: Reduced from 0.006 (more hardy)
		"waste": 0.0,
		"toxicity_sensitivity": 0.15
	},
	"hydra": {
		"unit_biomass": 8.0,
		"soft_biomass": 6.0,
		"hard_biomass": 2.0,
		"respiration": 0.01,  # v3 FIX: Reduced from 0.015
		"death": 0.015,  # v3 FIX: Reduced from 0.025
		"waste": 0.01,
		"toxicity_sensitivity": 0.3
	},
	"bacteria": {
		"unit_biomass": 1.0,
		"soft_biomass": 0.8,
		"hard_biomass": 0.2,
		"respiration": 0.008,
		"death": 0.006,  # v3 FIX: Reduced from 0.012 (50% reduction - bacteria are hardy!)
		"waste": 0.003,
		"toxicity_sensitivity": 0.0
	},
	"blackworms": {
		"unit_biomass": 2.0,
		"soft_biomass": 1.6,
		"hard_biomass": 0.2,
		"respiration": 0.015,
		"death": 0.012,
		"waste": 0.005,
		"toxicity_sensitivity": 0.2
	},
	"cyclops": {
		"unit_biomass": 1.5,
		"soft_biomass": 1.2,
		"hard_biomass": 0.3,
		"respiration": 0.014,
		"death": 0.022,
		"waste": 0.007,
		"toxicity_sensitivity": 0.35
	}
}


## BALANCE FIX: Reduced predation rates to prevent instant prey collapse
## Added bacteria as food source for filter feeders and detritivores
@export var food_web: Dictionary = {
	"hydra": {
		"daphnia": 0.0008,
		"cyclops": 0.0006,
		"planarian": 0.0007,  # v3 FIX: Increased from 0.0004 (5x increase!)
	},
	"cyclops": {
		"daphnia": 0.0004,
		"algae": 0.0005,
		"bacteria": 0.0005,  # v3 FIX: Reduced from 0.0008
		"planarian": 0.0008,  # v3 FIX: NEW - cyclops now hunt planarians!
	},
	"daphnia": {
		"algae": 0.0006,
		"bacteria": 0.0003,  # v3 FIX: Reduced from 0.0005
	},
	"snail": {
		"algae": 0.0005,
		"volvox": 0.0008,
		"elodea": 0.0006,  # v3 FIX: Reduced from 0.0012 (50% reduction)
		"soft_detritus": 0.001,
		"bacteria": 0.0002,  # v3 FIX: Reduced from 0.0003
	},
	"bacteria": {
		"soft_detritus": 0.015,
		"toxic_waste": 0.025,
	},
	"blackworms": {
		"soft_detritus": 0.008,
		"bacteria": 0.0003,  # v3 FIX: Reduced from 0.006 (!!!)
	},
}


## --- EXTERNAL FACTORS ---
## These factors represent environmental conditions that affect the simulation

@export var light_intensity: float = 1.0  # Range: 0.0 (dark) to 2.0 (bright sun)
@export var temperature: float = 25.0     # In Celsius, range: 15-30
@export var tank_volume: float = 1.0      # In Liters


## --- SIMULATION STATE ---
var simulation_time: float = 0.0  # Total elapsed simulation time in seconds
var frame_count: int = 0
var print_interval: int = 10  # Print every N frames


## --- PHYSICS PROCESS ---
## Uses fixed timestep for numerical stability
## Only runs during simulation phase and when not paused

func _ready():
	add_to_group("main")
#	for species in populations.keys():
#		var new_node2d : Node2D = Node2D.new()
#		new_node2d.name = species.capitalize()
#		visual_container.add_child(new_node2d)
#	for child in visual_container.get_children():
#		child.set_script(pop_visualizer)

func _physics_process(delta: float) -> void:
	# Only advance simulation during simulation phase and when not paused
	if GameState.is_simulation_phase() and Engine.time_scale > 0.0:
		advance_simulation(delta)


## --- CORE SIMULATION LOGIC ---
## This function executes one step of the simulation

func advance_simulation(step_delta: float) -> void:
	# 1. Initialize delta trackers
	var oxygen_delta: float = 0.0
	var co2_delta: float = 0.0
	var nutrient_delta: float = 0.0
	var soft_detritus_delta: float = 0.0
	var hard_detritus_delta: float = 0.0
	var toxic_waste_delta: float = 0.0

	var population_deltas: Dictionary = {}
	for species in populations.keys():
		population_deltas[species] = 0.0

	# 2. Producers (Photosynthesis)
	#    Algae, volvox, and elodea consume CO2 and nutrient_pool to grow
	#    Growth is limited by the least available resource (light, CO2, or nutrients)
	#    Production of oxygen occurs here
	#    BALANCE FIX: Now properly scaled by step_delta for consistent time-based behavior

	# Algae production
	var algae_biomass = populations.get("algae", 0.0)
	if algae_biomass > 0.0:
		var producer_rate = algae_biomass * 0.015 * light_intensity * step_delta
		var co2_available = co2 / max(tank_volume * 100.0, 1.0)
		var nutrient_available = nutrient_pool / max(tank_volume * 100.0, 1.0)

		producer_rate *= min(co2_available, nutrient_available, 1.0)

		if producer_rate > 0.0:
			co2_delta -= producer_rate * 0.5
			nutrient_delta -= producer_rate * 0.3
			oxygen_delta += producer_rate * 1.2  # v3 FIX: Increased from 0.7 (70% more oxygen!)
			population_deltas["algae"] += producer_rate * 0.08

	# Elodea production (multicellular plant - more efficient photosynthesis)
	var elodea_biomass = populations.get("elodea", 0.0)
	if elodea_biomass > 0.0:
		var producer_rate = elodea_biomass * 0.02 * light_intensity * step_delta
		var co2_available = co2 / max(tank_volume * 100.0, 1.0)
		var nutrient_available = nutrient_pool / max(tank_volume * 100.0, 1.0)

		producer_rate *= min(co2_available, nutrient_available, 1.0)

		if producer_rate > 0.0:
			co2_delta -= producer_rate * 0.6
			nutrient_delta -= producer_rate * 0.4
			oxygen_delta += producer_rate * 1.5  # v3 FIX: Increased from 0.9 (67% more oxygen!)
			population_deltas["elodea"] += producer_rate * 0.05

		# 3. Decomposers (Recycling)
	#    v3 FIX: Dramatically increased bacteria growth from decomposition work

	var bacteria_biomass = populations.get("bacteria", 0.0)
	
	# Process soft detritus
	if bacteria_biomass > 0.0 and soft_detritus > 0.0:
		var decomposition_rate = min(bacteria_biomass * 0.02 * step_delta, soft_detritus * 0.15)
		soft_detritus_delta -= decomposition_rate
		toxic_waste_delta += decomposition_rate * 0.3
		nutrient_delta += decomposition_rate * 0.7

	# Process toxic waste (bacteria's most important job!)
	if bacteria_biomass > 0.0 and toxic_waste > 0.0:
		var detox_rate = min(bacteria_biomass * 0.025 * step_delta, toxic_waste * 0.2)
		toxic_waste_delta -= detox_rate
		nutrient_delta += detox_rate * 0.9
		population_deltas["bacteria"] += detox_rate * 0.25  # v3 FIX: Increased from 0.05 (4x growth!)

	# 4. Hard Detritus Decay
	#    A very slow, passive process where hard_detritus breaks down

	var decay_rate = hard_detritus * 0.0008 * step_delta
	hard_detritus_delta -= decay_rate
	soft_detritus_delta += decay_rate * 0.7
	nutrient_delta += decay_rate * 0.3

	# 5. Consumers (Predation)
	#    v3 FIX: Hydra → planarian rate increased, cyclops → planarian added

	for predator in food_web.keys():
		var predator_biomass = populations.get(predator, 0.0)
		if predator_biomass <= 0.0:
			continue

		for prey in food_web[predator].keys():
			var prey_biomass = populations.get(prey, 0.0)
			if prey_biomass <= 0.0 and prey != "soft_detritus" and prey != "toxic_waste":
				continue

			var interaction_rate = food_web[predator][prey]
			var feeding_rate = predator_biomass * interaction_rate * step_delta

			# Handle special cases for non-living food sources
			if prey == "soft_detritus":
				feeding_rate = min(feeding_rate, soft_detritus * 0.1)
				soft_detritus_delta -= feeding_rate
				population_deltas[predator] += feeding_rate * 0.25
			elif prey == "toxic_waste":
				feeding_rate = min(feeding_rate, toxic_waste * 0.15)
				toxic_waste_delta -= feeding_rate
				population_deltas[predator] += feeding_rate * 0.08
			else:
				# Normal predator-prey interaction
				var max_feeding = prey_biomass * 0.3
				feeding_rate = min(feeding_rate * prey_biomass, max_feeding)
				population_deltas[prey] -= feeding_rate
				population_deltas[predator] += feeding_rate * 0.25

	# 5.5 Special Egg/Juvenile Predation (Growth Limiters)
	#    Planarians eat snail eggs and young snails
	#    This REDUCES SNAIL GROWTH rather than killing adults

	var planarian_biomass = populations.get("planarian", 0.0)
	var snail_biomass = populations.get("snail", 0.0)
	var snail_egg_loss: float = 0.0
	
	if planarian_biomass > 0.0 and snail_biomass > 0.0:
		snail_egg_loss = planarian_biomass * 0.008 * step_delta
		
		var juvenile_predation = snail_biomass * planarian_biomass * 0.0002 * step_delta
		juvenile_predation = min(juvenile_predation, snail_biomass * 0.1)
		
		population_deltas["snail"] -= juvenile_predation
		population_deltas["planarian"] += juvenile_predation * 0.3

	# 6. Metabolism & Death
	#    v3 FIX: Reduced death rates for plants (algae, elodea)

	for species in populations.keys():
		var biomass = populations[species]
		if biomass <= 0.0:
			continue

		var params = species_params.get(species, {})
		if params.is_empty():
			continue

		# Respiration
		var respiration_rate = biomass * params.get("respiration", 0.01) * step_delta
		oxygen_delta -= respiration_rate
		co2_delta += respiration_rate

		# Waste production
		var waste_rate = biomass * params.get("waste", 0.02) * step_delta
		toxic_waste_delta += waste_rate

		# Death
		var death_rate = biomass * params.get("death", 0.01) * step_delta
		population_deltas[species] -= death_rate

		var soft_fraction = params.get("soft_biomass", 1.0) / max(params.get("unit_biomass", 1.0), 0.1)
		var hard_fraction = params.get("hard_biomass", 0.0) / max(params.get("unit_biomass", 1.0), 0.1)

		soft_detritus_delta += death_rate * soft_fraction
		hard_detritus_delta += death_rate * hard_fraction
		
		# Special: Snail natural reproduction
		if species == "snail" and biomass > 5.0:
			var snail_growth_rate = biomass * 0.015 * step_delta
			snail_growth_rate = max(0.0, snail_growth_rate - snail_egg_loss)
			population_deltas["snail"] += snail_growth_rate
		
		# Special: Planarian growth when eating eggs
		# v3 FIX: Reduced detritus bonus from 0.3 to 0.15
		if species == "planarian" and soft_detritus > 10.0:
			var planarian_growth = biomass * params.get("growth_rate", 0.06) * 0.15 * step_delta  # v3 FIX
			population_deltas["planarian"] += planarian_growth
			soft_detritus_delta -= planarian_growth * 0.5

	# 7. Toxicity Feedback
	#    High levels of toxic_waste increase death rate for all organisms

	var toxicity_level = toxic_waste / max(tank_volume * 50.0, 1.0)
	if toxicity_level > 1.0:
		for species in populations.keys():
			var params = species_params.get(species, {})
			var sensitivity = params.get("toxicity_sensitivity", 0.1)
			var toxicity_death = populations[species] * sensitivity * (toxicity_level - 1.0) * 0.08 * step_delta
			population_deltas[species] -= toxicity_death

	# 8. Apply all calculated deltas to the master variables
	#    After all local changes are calculated, apply them to the state

	oxygen = max(0.0, oxygen + oxygen_delta)
	co2 = max(0.0, co2 + co2_delta)
	nutrient_pool = max(0.0, nutrient_pool + nutrient_delta)
	soft_detritus = max(0.0, soft_detritus + soft_detritus_delta)
	hard_detritus = max(0.0, hard_detritus + hard_detritus_delta)
	toxic_waste = max(0.0, toxic_waste + toxic_waste_delta)

	for species in population_deltas.keys():
		populations[species] = max(0.0, populations[species] + population_deltas[species])

	# Update simulation time
	simulation_time += step_delta
	frame_count += 1

	# Print status periodically
	if frame_count % print_interval == 0:
		_print_status()


## --- HELPER FUNCTIONS ---

func get_elapsed_time_formatted() -> String:
	"""Returns simulation time formatted as HH:MM:SS"""
	var total_seconds = int(simulation_time)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func get_elapsed_days() -> float:
	"""Returns simulation time in days (useful for long-term tracking)"""
	return simulation_time / 86400.0  # 86400 seconds in a day


## --- DEBUG OUTPUT ---

func _print_status() -> void:
	print("\n=== Simulation Frame %d (Time: %s) ===" % [frame_count, get_elapsed_time_formatted()])
	print("--- Resources ---")
	print("  Oxygen: %.2f | CO2: %.2f | Nutrients: %.2f" % [oxygen, co2, nutrient_pool])
	print("  Soft Detritus: %.2f | Hard Detritus: %.2f | Toxic Waste: %.2f" % [soft_detritus, hard_detritus, toxic_waste])
	print("--- Populations ---")
	for species in populations.keys():
		print("  %s: %.2f" % [species.capitalize(), populations[species]])
	print("--- Environment ---")
	print("  Light: %.2f | Temperature: %.1f°C | Tank Volume: %.2f L" % [light_intensity, temperature, tank_volume])


## --- SETUP PHASE FUNCTIONS (GDD 4.4, Implementation Plan 3.2) ---

func add_organism(species_name: String) -> void:
	"""Add one unit of a species to the jar during setup phase."""
	if not GameState.is_setup_phase():
		return

	var params = species_params.get(species_name)
	if not params:
		push_error("Unknown species: %s" % species_name)
		return

	var unit_biomass = params.get("unit_biomass", 1.0)
	populations[species_name] = populations.get(species_name, 0.0) + unit_biomass
	print("Added 1x %s (biomass: %.1f)" % [species_name.capitalize(), unit_biomass])


func remove_organism(species_name: String) -> void:
	"""Remove one unit of a species from the jar during setup phase."""
	if not GameState.is_setup_phase():
		return

	var params = species_params.get(species_name)
	if not params:
		push_error("Unknown species: %s" % species_name)
		return

	var unit_biomass = params.get("unit_biomass", 1.0)
	var current = populations.get(species_name, 0.0)

	if current >= unit_biomass:
		populations[species_name] -= unit_biomass
		print("Removed 1x %s (biomass: %.1f)" % [species_name.capitalize(), unit_biomass])
	else:
		print("Cannot remove %s - insufficient biomass" % species_name)


func add_resource(resource_name: String, amount: float) -> void:
	"""Add initial resource amounts during setup phase."""
	if not GameState.is_setup_phase():
		return

	match resource_name:
		"oxygen":
			oxygen += amount
		"co2":
			co2 += amount
		"nutrient_pool":
			nutrient_pool += amount
		"soft_detritus":
			soft_detritus += amount
		"hard_detritus":
			hard_detritus += amount
		_:
			push_error("Unknown resource: %s" % resource_name)
			return

	print("Added %.1f to %s" % [amount, resource_name])


func reset_jar() -> void:
	"""Reset the jar to empty state for setup phase."""
	# Clear all populations
	for species in populations.keys():
		populations[species] = 0.0

	# Reset resources to default
	oxygen = 21000.0
	co2 = 400.0
	nutrient_pool = 100.0
	soft_detritus = 50.0
	hard_detritus = 200.0
	toxic_waste = 0.0

	# Reset simulation state
	simulation_time = 0.0
	frame_count = 0
	$UI.setup_panel.visible = true 

	print("Jar reset to empty state")


func seal_jar() -> void:
	"""Seal the jar and transition to simulation phase."""
	GameState.enter_simulation_phase()
	print("Jar sealed! Simulation starting...")
