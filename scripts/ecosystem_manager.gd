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

## --- SPECIES DATA (GDD 3.2) ---
## All species data is stored in flexible Dictionaries for easy modification and expansion

@export var populations: Dictionary = {
	"algae": 100.0,
	"volvox": 0.0,
	"elodea": 50.0,
	"daphnia": 20.0,
	"snail": 10.0,
	"planarian": 5.0,
	"hydra": 5.0,
	"bacteria": 50.0,
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
		"waste": 0.008,  # REDUCED from 0.03
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
		"growth_rate": 0.12  # Special: fast reproduction when food available
	},
	"daphnia": {
		"unit_biomass": 2.0,
		"soft_biomass": 1.5,
		"hard_biomass": 0.5,
		"respiration": 0.012,
		"death": 0.02,
		"waste": 0.006,  # REDUCED from 0.02
		"toxicity_sensitivity": 0.4
	},
	"algae": {
		"unit_biomass": 5.0,
		"soft_biomass": 4.0,
		"hard_biomass": 1.0,
		"respiration": 0.004,
		"death": 0.008,
		"waste": 0.0,  # Algae produce minimal waste
		"toxicity_sensitivity": 0.1
	},
	"volvox": {
		"unit_biomass": 3.0,
		"soft_biomass": 2.0,
		"hard_biomass": 1.0,
		"respiration": 0.004,
		"death": 0.008,
		"waste": 0.0,  # Volvox produce minimal waste
		"toxicity_sensitivity": 0.1
	},
	"elodea": {
		"unit_biomass": 20.0,
		"soft_biomass": 15.0,
		"hard_biomass": 5.0,
		"respiration": 0.003,  # Lower respiration (efficient photosynthesizer)
		"death": 0.006,  # Slow-growing, long-lived plant
		"waste": 0.0,  # Plants produce no nitrogenous waste
		"toxicity_sensitivity": 0.15  # Reasonably tolerant
	},
	"hydra": {
		"unit_biomass": 8.0,
		"soft_biomass": 6.0,
		"hard_biomass": 2.0,
		"respiration": 0.015,
		"death": 0.025,
		"waste": 0.01,  # REDUCED from 0.04
		"toxicity_sensitivity": 0.3
	},
	"bacteria": {
		"unit_biomass": 1.0,
		"soft_biomass": 0.8,
		"hard_biomass": 0.2,
		"respiration": 0.008,
		"death": 0.012,
		"waste": 0.003,  # REDUCED from 0.02 - bacteria should clean, not pollute!
		"toxicity_sensitivity": 0.0
	},
	"blackworms": {
		"unit_biomass": 2.0,
		"soft_biomass": 1.6,
		"hard_biomass": 0.2,
		"respiration": 0.015,
		"death": 0.012,
		"waste": 0.005,  # REDUCED from 0.02
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
		"daphnia": 0.0008,  # REDUCED from 0.003
		"cyclops": 0.0006,  # Cyclops are also prey
		"planarian": 0.0004,  # Hydra eat small planarians
	},
	"cyclops": {
		"daphnia": 0.0004,  # Cyclops eat daphnia
		"algae": 0.0005,  # Cyclops also graze on algae
		"bacteria": 0.0008,  # Filter feeding
	},
	"daphnia": {
		"algae": 0.0006,  # REDUCED from 0.002
		"bacteria": 0.0005,  # Filter feeders consume bacteria
	},
	"snail": {
		"algae": 0.0005,  # REDUCED from 0.002
		"volvox": 0.0008,  # REDUCED from 0.003
		"elodea": 0.0012,  # Snails LOVE elodea - higher rate
		"soft_detritus": 0.001,  # REDUCED from 0.003
		"bacteria": 0.0003,  # Grazing on biofilm
	},
	"bacteria": {
		"soft_detritus": 0.015,  # Increased to clean up detritus faster
		"toxic_waste": 0.025,  # Increased to process toxic waste faster
	},
	"blackworms": {
		"soft_detritus": 0.008,  # REDUCED from 0.01
		"bacteria": 0.006,  # Detritivores consume bacteria in sediment
	},
}

## --- EXTERNAL FACTORS ---
## These factors represent environmental conditions that affect the simulation

@export var light_intensity: float = 1.0  # Range: 0.0 (dark) to 2.0 (bright sun)
@export var temperature: float = 25.0     # In Celsius, range: 15-30
@export var tank_volume: float = 1.0      # In Liters


## --- SIMULATION STATE ---
var simulation_time: float = 0.0
var frame_count: int = 0
var print_interval: int = 10  # Print every N frames


## --- PHYSICS PROCESS ---
## Uses fixed timestep for numerical stability
## Only runs during simulation phase and when not paused

#func _ready():
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
		# Scale by step_delta to make photosynthesis time-based (per second)
		var producer_rate = algae_biomass * 0.015 * light_intensity * step_delta
		var co2_available = co2 / max(tank_volume * 100.0, 1.0)
		var nutrient_available = nutrient_pool / max(tank_volume * 100.0, 1.0)

		# Limited by least available resource (clamp to 1.0 max)
		producer_rate *= min(co2_available, nutrient_available, 1.0)

		if producer_rate > 0.0:
			co2_delta -= producer_rate * 0.5
			nutrient_delta -= producer_rate * 0.3
			oxygen_delta += producer_rate * 0.7
			population_deltas["algae"] += producer_rate * 0.08  # Growth rate

	# Elodea production (multicellular plant - more efficient photosynthesis)
	var elodea_biomass = populations.get("elodea", 0.0)
	if elodea_biomass > 0.0:
		# Elodea is more efficient at photosynthesis than algae
		var producer_rate = elodea_biomass * 0.02 * light_intensity * step_delta
		var co2_available = co2 / max(tank_volume * 100.0, 1.0)
		var nutrient_available = nutrient_pool / max(tank_volume * 100.0, 1.0)

		# Limited by least available resource
		producer_rate *= min(co2_available, nutrient_available, 1.0)

		if producer_rate > 0.0:
			co2_delta -= producer_rate * 0.6  # Uses more CO2
			nutrient_delta -= producer_rate * 0.4  # Uses more nutrients
			oxygen_delta += producer_rate * 0.9  # Produces more oxygen
			population_deltas["elodea"] += producer_rate * 0.05  # Slower growth (larger biomass)

	# 3. Decomposers (Recycling)
	#    Bacteria primarily consume soft_detritus, converting it into toxic_waste
	#    They also consume toxic_waste and convert it into nutrient_pool
	#    This is the core of the nitrogen cycle
	#    BALANCE FIX: Adjusted conversion rates to prevent toxic waste buildup

	var bacteria_biomass = populations.get("bacteria", 0.0)
	
	# Process soft detritus
	if bacteria_biomass > 0.0 and soft_detritus > 0.0:
		# Scale by step_delta to make decomposition time-based (per second)
		var decomposition_rate = min(bacteria_biomass * 0.02 * step_delta, soft_detritus * 0.15)
		soft_detritus_delta -= decomposition_rate
		# BALANCE FIX: Reduced toxic waste production, increased nutrient production
		toxic_waste_delta += decomposition_rate * 0.3  # REDUCED from 0.6
		nutrient_delta += decomposition_rate * 0.7  # INCREASED from 0.4

	# Process toxic waste (bacteria's most important job!)
	if bacteria_biomass > 0.0 and toxic_waste > 0.0:
		var detox_rate = min(bacteria_biomass * 0.025 * step_delta, toxic_waste * 0.2)
		toxic_waste_delta -= detox_rate
		nutrient_delta += detox_rate * 0.9  # Most of the waste becomes nutrients
		population_deltas["bacteria"] += detox_rate * 0.05  # Bacteria grow from this

	# 4. Hard Detritus Decay
	#    A very slow, passive process where hard_detritus breaks down
	#    Releases stored mass into soft_detritus or directly into nutrient_pool

	# Scale by step_delta to make decay time-based (per second), not frame-based
	var decay_rate = hard_detritus * 0.0008 * step_delta  # Very slow decay
	hard_detritus_delta -= decay_rate
	soft_detritus_delta += decay_rate * 0.7
	nutrient_delta += decay_rate * 0.3

	# 5. Consumers (Predation)
	#    Parse the food_web dictionary
	#    For each predator, calculate food intake based on:
	#    - Predator density
	#    - Prey density
	#    - Interaction rate
	#    Prey biomass decreases, predator biomass increases (with energy loss)
	#    BALANCE FIX: Reduced interaction rates in food_web dictionary

	for predator in food_web.keys():
		var predator_biomass = populations.get(predator, 0.0)
		if predator_biomass <= 0.0:
			continue

		for prey in food_web[predator].keys():
			var prey_biomass = populations.get(prey, 0.0)
			if prey_biomass <= 0.0 and prey != "soft_detritus" and prey != "toxic_waste":
				continue

			var interaction_rate = food_web[predator][prey]
			# Scale by step_delta to make interaction rates time-based (per second)
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
				# BALANCE FIX: Limit feeding to prevent instant prey collapse
				var max_feeding = prey_biomass * 0.3  # Max 30% of prey per timestep
				feeding_rate = min(feeding_rate * prey_biomass, max_feeding)
				population_deltas[prey] -= feeding_rate
				population_deltas[predator] += feeding_rate * 0.25  # Energy loss

	# 5.5 Special Egg/Juvenile Predation (Growth Limiters)
	#    Planarians eat snail eggs and young snails
	#    This REDUCES SNAIL GROWTH rather than killing adults
	#    Creates population control without decimating existing snails
	#    BALANCE: This is the ONLY control on snail populations!

	var planarian_biomass = populations.get("planarian", 0.0)
	var snail_biomass = populations.get("snail", 0.0)
	var snail_egg_loss: float = 0.0  # Track egg predation separately
	
	if planarian_biomass > 0.0 and snail_biomass > 0.0:
		# Planarians reduce snail reproduction by consuming eggs/juveniles
		# This COUNTERACTS snail population growth, not the base population
		snail_egg_loss = planarian_biomass * 0.008 * step_delta
		
		# Small drain on existing adult population (eating very young snails)
		var juvenile_predation = snail_biomass * planarian_biomass * 0.0002 * step_delta
		juvenile_predation = min(juvenile_predation, snail_biomass * 0.1)  # Max 10% of adults
		
		population_deltas["snail"] -= juvenile_predation
		population_deltas["planarian"] += juvenile_predation * 0.3  # Energy gain

	# 6. Metabolism & Death
	#    Iterate through all species
	#    Each species consumes oxygen and produces CO2 (respiration)
	#    Each species excretes toxic_waste
	#    Snails have natural reproduction (limited by planarian egg predation)
	#    When organisms die:
	#      - soft_biomass goes to soft_detritus pool
	#      - hard_biomass goes to hard_detritus pool
	#    BALANCE FIX: Reduced waste production rates in species_params

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

		# Waste production (REDUCED in species_params)
		var waste_rate = biomass * params.get("waste", 0.02) * step_delta
		toxic_waste_delta += waste_rate

		# Death
		var death_rate = biomass * params.get("death", 0.01) * step_delta
		population_deltas[species] -= death_rate

		var soft_fraction = params.get("soft_biomass", 1.0) / max(params.get("unit_biomass", 1.0), 0.1)
		var hard_fraction = params.get("hard_biomass", 0.0) / max(params.get("unit_biomass", 1.0), 0.1)

		soft_detritus_delta += death_rate * soft_fraction
		hard_detritus_delta += death_rate * hard_fraction
		
		# Special: Snail natural reproduction (if no predators exist)
		# This gets REDUCED by planarian egg predation
		if species == "snail" and biomass > 5.0:  # Need minimum population to reproduce
			var snail_growth_rate = biomass * 0.015 * step_delta  # Natural reproduction
			
			# Subtract egg predation (planarians eating eggs)
			# snail_egg_loss is calculated earlier in section 5.5
			snail_growth_rate = max(0.0, snail_growth_rate - snail_egg_loss)
			
			# Add the net growth (reproduction - egg predation)
			population_deltas["snail"] += snail_growth_rate
		
		# Special: Planarian growth when eating eggs
		# (growth from egg consumption happens in predation section above)
		# This adds baseline growth if detritus available
		if species == "planarian" and soft_detritus > 10.0:
			var planarian_growth = biomass * params.get("growth_rate", 0.12) * 0.3 * step_delta
			population_deltas["planarian"] += planarian_growth
			soft_detritus_delta -= planarian_growth * 0.5  # Consume some detritus

	# 7. Toxicity Feedback
	#    High levels of toxic_waste increase death rate for all organisms
	#    Effect scaled by individual species toxicity_sensitivity

	var toxicity_level = toxic_waste / max(tank_volume * 50.0, 1.0)
	if toxicity_level > 1.0:
		for species in populations.keys():
			var params = species_params.get(species, {})
			var sensitivity = params.get("toxicity_sensitivity", 0.1)
			var toxicity_death = populations[species] * sensitivity * (toxicity_level - 1.0) * 0.08 * step_delta
			population_deltas[species] -= toxicity_death

	# 8. Apply all calculated deltas to the master variables
	#    After all local changes are calculated, apply them to the state
	#    Ensure no resource goes negative

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


## --- DEBUG OUTPUT ---

func _print_status() -> void:
	print("\n=== Simulation Frame %d (Time: %.2fs) ===" % [frame_count, simulation_time])
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

	print("Jar reset to empty state")


func seal_jar() -> void:
	"""Seal the jar and transition to simulation phase."""
	GameState.enter_simulation_phase()
	print("Jar sealed! Simulation starting...")
