## GameState.gd
##
## Global autoload script for managing game state.
## Tracks the current game phase and other global game settings.
##
## Usage: Add to project autoload in Project Settings > Autoload
## Then access globally as: GameState.current_state
##
## References:
## - Implementation Plan Section 3.1: Game State Manager

extends Node

## Game phases
enum State { SETUP, SIMULATION }

## Current game state
var current_state: State = State.SETUP

## Game settings
var beginner_mode: bool = false
var tank_volume: float = 1.0


## --- SETUP PHASE FUNCTIONS ---

func enter_setup_phase() -> void:
	"""Transition to setup phase."""
	current_state = State.SETUP
	print("Entered SETUP phase")


func enter_simulation_phase() -> void:
	"""Transition to simulation phase."""
	current_state = State.SIMULATION
	print("Entered SIMULATION phase")


## --- UTILITY FUNCTIONS ---

func is_setup_phase() -> bool:
	"""Check if currently in setup phase."""
	return current_state == State.SETUP


func is_simulation_phase() -> bool:
	"""Check if currently in simulation phase."""
	return current_state == State.SIMULATION


func set_beginner_mode(enabled: bool) -> void:
	"""Toggle beginner mode difficulty."""
	beginner_mode = enabled
	print("Beginner mode: %s" % ("ON" if enabled else "OFF"))


func set_tank_volume(volume: float) -> void:
	"""Set the tank volume for the current session."""
	tank_volume = max(0.5, volume)  # Minimum 0.5L
	print("Tank volume set to: %.1fL" % tank_volume)
