# **Implementation Plan: Biosphere Jar**

This document outlines the technical implementation strategy for the "Biosphere Jar" project. It integrates the features specified in the **Game Design Document (GDD)** with the architectural best practices detailed in the **Ecosystem Simulation Design Principles** document.

### **Guiding Principles**

This plan is built on three core principles derived from the design documents:

1. **Simulation First (Principle 2.1.1):** The numerical stability of the ecosystem model is paramount. All core logic will be decoupled from rendering and executed on a fixed timestep to ensure deterministic, reproducible results.  
2. **Data-Driven Design (GDD 3.2):** The ecosystem's rules (species parameters, food web) will be defined in exported data structures (Dictionaries), not hard-coded. This allows for rapid iteration, balancing, and the future addition of new species without code rewrites.  
3. **UI as an Abstraction Layer (Principle 3.1.1):** The UI's primary goal is to translate complex simulation data into clear, actionable feedback for the player, reducing cognitive load.

## **Phase 1: The Core Simulation Engine**

**Goal:** Create a non-visual, purely mathematical simulation that correctly models the resource and population dynamics as defined in the GDD.

### **1.1. Scene & Script Structure**

* **Node Structure:** Create a main scene with a single Node named EcosystemManager.  
* **Script EcosystemManager.gd:** This will be the "brain" of the simulation. It will contain all resource pools, population data, and the core logic loop.

### **1.2. Data Structures (GDD 3.2)**

Implement the core dictionaries in EcosystemManager.gd. Using @export will allow for easy editing in the Godot Inspector.

\# EcosystemManager.gd  
extends Node

\# \--- RESOURCE POOLS (GDD 3.1) \---  
@export var oxygen: float \= 21000.0  
@export var co2: float \= 400.0  
\# ... etc. for all pools

\# \--- SPECIES DATA (GDD 3.2) \---  
@export var populations: Dictionary \= {"algae": 100.0, "daphnia": 20.0}  
@export var species\_params: Dictionary \= {  
	"snail": {"unit\_biomass": 15.0, "soft\_biomass": 5.0, "hard\_biomass": 10.0, "respiration": 0.01, "death": 0.02, "waste": 0.03, "toxicity\_sensitivity": 0.2}  
}  
@export var food\_web: Dictionary \= {  
	"hydra": {"daphnia": 0.01, "cyclops": 0.008}  
}

\# \--- EXTERNAL FACTORS \---  
@export var light\_intensity: float \= 1.0  
@export var temperature: float \= 25.0  
@export var tank\_volume: float \= 1.0 \# In Liters

### **1.3. The Fixed Timestep Logic Loop (Principle 2.1.1)**

The GDD specifies an advance\_simulation(delta) function. To ensure numerical stability, this function **must** be called from Godot's \_physics\_process(delta) loop, not \_process(delta).

\# In EcosystemManager.gd

\# \_physics\_process provides the fixed timestep required for stable simulation.  
func \_physics\_process(delta: float) \-\> void:  
    advance\_simulation(delta)

\# The main logic function, separated for headless execution ("Skip Ahead").  
func advance\_simulation(step\_delta: float) \-\> void:  
    \# This is where all the logic from GDD 3.3 will be implemented.  
    \# 1\. Initialize delta trackers  
    \# 2\. Producers (Photosynthesis)  
    \# 3\. Decomposers (Recycling)  
    \# 4\. Hard Detritus Decay  
    \# 5\. Consumers (Predation)  
    \# 6\. Metabolism & Death  
    \# 7\. Toxicity Feedback  
    \# 8\. Apply all calculated deltas to the master variables  
    pass

**Phase 1 Deliverable:** A project that, when run, prints the changing values of populations and resources to the console. The simulation should be stable and produce logical outcomes (e.g., algae dying in the dark, predators dying without prey).

## **Phase 2: Visualization and UI**

**Goal:** Connect the running simulation to a visual front-end, allowing the player to *see* the state of the ecosystem.

### **2.1. Decoupled Visuals (GDD 8.2)**

* **Node Structure:** Add two child nodes to the main scene: VisualContainer (Node2D) and UI (CanvasLayer).  
* **PopulationVisualizer.gd Script:** This script will be attached to child nodes within VisualContainer (e.g., one for "Daphnia," one for "Snails"). It reads data from EcosystemManager but never writes to it.

\# PopulationVisualizer.gd  
extends Node2D

@export var manager\_path: NodePath  
@export var species\_name: String  
@export var creature\_scene: PackedScene  
@export var density\_per\_sprite: float \= 5.0

var manager: Node

func \_ready() \-\> void:  
    manager \= get\_node(manager\_path)

\# Use \_process for smooth visual updates, independent of the simulation tick.  
func \_process(delta: float) \-\> void:  
    if not is\_instance\_valid(manager):  
        return

    var density \= manager.populations.get(species\_name, 0.0)  
    var target\_count \= int(density / density\_per\_sprite)

    var current\_count \= get\_child\_count()  
    if current\_count \< target\_count:  
        var creature \= creature\_scene.instantiate()  
        add\_child(creature)  
        \# Position it randomly within the jar bounds  
    elif current\_count \> target\_count:  
        if get\_child\_count() \> 0:  
            get\_child(0).queue\_free()

### **2.2. HUD and Data Abstraction (Principle 3.2.1)**

The HUD will display resource levels. To reduce cognitive load, we will display 3-5 primary indicators, with detailed stats in a separate panel.

* **Node Structure:** Inside the UI node, add a VBoxContainer for the resource bars.  
* **UIManager.gd Script:** This script, attached to the UI node, will bridge the EcosystemManager data to the UI elements.

\# UIManager.gd  
extends CanvasLayer

@onready var oxygen\_bar: ProgressBar \= $VBoxContainer/OxygenBar  
@onready var co2\_label: Label \= $VBoxContainer/CO2Label  
\# ... references to other UI elements

var manager: Node

func \_ready() \-\> void:  
    \# Await the manager being ready  
    manager \= get\_node("/root/MainScene/EcosystemManager")

func \_process(delta: float) \-\> void:  
    if not is\_instance\_valid(manager):  
        return

    \# Directly map some values  
    oxygen\_bar.value \= manager.oxygen  
    co2\_label.text \= "CO2: %.2f" % manager.co2

    \# Abstracted Value (Principle 3.1.1)  
    var toxicity\_index \= manager.toxic\_waste / (50.0 \* manager.tank\_volume) \# Normalized 0-1+  
    \# Update a "Toxicity" or "Water Quality" bar with this value.

**Phase 2 Deliverable:** A visual representation of the jar with sprites appearing/disappearing based on population density. A basic HUD displays real-time values from the simulation.

## **Phase 3: Player Interaction & Game Loop**

**Goal:** Implement the two-phase game loop (Setup/Simulation) and all player controls.

### **3.1. Game State Manager**

Create an enum in a global autoload script (GameState.gd) to manage the current game phase.  
enum State { SETUP, SIMULATION }  
The EcosystemManager and UIManager will check this global state to enable/disable functionality.

### **3.2. Setup Phase Toolbox (GDD 6.2)**

* The UIManager will be responsible for the Setup UI.  
* Buttons in the toolbox will call functions on the EcosystemManager.

\# In UIManager.gd, connected to a button's "pressed" signal  
func \_on\_add\_snail\_button\_pressed() \-\> void:  
	if GameState.current\_state \== GameState.State.SETUP:  
		manager.add\_organism("snail")

\# In EcosystemManager.gd  
func add\_organism(species\_name: String) \-\> void:  
	var params \= species\_params.get(species\_name)  
	if params:  
		var unit\_biomass \= params.get("unit\_biomass", 1.0)  
		populations\[species\_name\] \= populations.get(species\_name, 0.0) \+ unit\_biomass

### **3.3. Time & Environment Controls (GDD 4.1, 4.3)**

* **Time Controls:** UI buttons will modify Engine.time\_scale.  
* **Skip Ahead:** Implement the async function as described in the GDD. This will call advance\_simulation() directly, bypassing the \_physics\_process loop.  
* **Environment Sliders:** Sliders in the UI will directly set the light\_intensity and temperature variables on the EcosystemManager.

**Phase 3 Deliverable:** The full gameplay loop is functional. The player can set up a jar, seal it, and then influence the running simulation with time, light, and temperature controls.

## **Phase 4: Advanced Features & Polish**

**Goal:** Add the remaining features from the GDD to create a complete, engaging experience.

### **4.1. Historical Data Graphing (Principle 3.2.3)**

To provide strategic feedback, especially after using "Skip Ahead," a history graph is essential.

* **Data Collection:** In EcosystemManager, create an array history\_log. Every N physics frames, append a dictionary of the current simulation state ({"time": time, "populations": populations.duplicate(), ...}) to this array.  
* **Visualization:** Create a new "History" screen. This screen will read the history\_log and use a Line2D node or a custom drawing function to plot the data, allowing players to review trends over time.

### **4.2. Challenges & Game Modes (GDD 5.1, 5.2)**

* Implement the beginner\_mode boolean. In the EcosystemManager, use this flag to modify key calculations (e.g., toxicity\_factor \*= 0.5).  
* Challenges can be implemented as separate scenes that pre-configure the EcosystemManager with specific starting conditions and display a unique UI with the challenge objective.

### **4.3. Educational Popups & SFX (GDD 5.3, 7.2)**

* Create a generic PopupPanel.tscn scene. Clicking on UI elements or organism sprites will call a function in UIManager that shows this panel and populates it with the relevant text content.  
* Add an AudioStreamPlayer node for background music and another for sound effects. Trigger SFX on button presses and key simulation events.

**Phase 4 Deliverable:** A polished and complete game experience with all features from the GDD implemented, including challenges, educational content, and audio.
