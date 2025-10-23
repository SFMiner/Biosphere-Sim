# **AI Agent Task: Implement Phase 1 of the Biosphere Jar Godot Project**

## **Role and Goal**

You are a Godot game developer. Your task is to create the initial GDScript file for the "Biosphere Jar" simulation project. Your work will form the core foundation of the game's engine. You must follow the provided implementation plan precisely.

## **Context**

We are building a 2D ecosystem simulation game in Godot 4.x called "Biosphere Jar." The project is guided by a Game Design Document (GDD) and a detailed Implementation Plan. This task is to complete **Phase 1: The Core Simulation Engine** as outlined in the implementation plan. The key principles are **Simulation First** and **Data-Driven Design**.

## **Your Task: Create EcosystemManager.gd**

You will write a single, complete GDScript file named EcosystemManager.gd. This script will be the "brain" of the simulation.

### **1\. Script Setup**

* The script must extend Node.  
* All variables that are intended to be tweaked by a designer must be exposed to the Godot Inspector using the @export annotation.

### **2\. Implement Data Structures (from Plan Section 1.2)**

* **Resource Pools:** Declare all resource pool variables as float. This includes oxygen, co2, soft\_detritus, hard\_detritus, nutrient\_pool, and toxic\_waste. Populate them with reasonable default values.  
* **Species Data:** Declare the three core data Dictionary variables: populations, species\_params, and food\_web. Populate them with the example data provided in the implementation plan to ensure they are functional.  
* **External Factors:** Declare the variables for light\_intensity, temperature, and tank\_volume.

### **3\. Implement the Fixed Timestep Logic Loop (from Plan Section 1.3)**

* Create the \_physics\_process(delta: float) function. The only thing this function should do is call advance\_simulation(delta).  
* Create the advance\_simulation(step\_delta: float) function. This function's body should be empty for now, but you **must** include the placeholder comments from the implementation plan that outline the future logic steps (e.g., \# 1\. Initialize delta trackers, \# 2\. Producers (Photosynthesis), etc.). This is crucial for the next phase of development.

## **Deliverable**

* A single, complete, and well-commented GDScript file (EcosystemManager.gd).  
* The script must be runnable in a Godot 4.x project (attached to a Node) without any errors.  
* Adherence to the variable names and structure defined in the implementation plan is mandatory.

## **Example Code Structure to Follow:**

\# EcosystemManager.gd  
extends Node

\# \--- RESOURCE POOLS (GDD 3.1) \---  
@export var oxygen: float \= 21000.0  
\# ... etc ...

\# \--- SPECIES DATA (GDD 3.2) \---  
@export var populations: Dictionary \= {"algae": 100.0, "daphnia": 20.0}  
\# ... etc ...

\# \--- EXTERNAL FACTORS \---  
@export var light\_intensity: float \= 1.0  
\# ... etc ...

\# \_physics\_process provides the fixed timestep required for stable simulation.  
func \_physics\_process(delta: float) \-\> void:  
	advance\_simulation(delta)

\# The main logic function, separated for headless execution ("Skip Ahead").  
func advance\_simulation(step\_delta: float) \-\> void:  
	\# 1\. Initialize delta trackers  
	\# 2\. Producers (Photosynthesis)  
	\# 3\. Decomposers (Recycling)  
	\# 4\. Hard Detritus Decay  
	\# 5\. Consumers (Predation)  
	\# 6\. Metabolism & Death  
	\# 7\. Toxicity Feedback  
	\# 8\. Apply all calculated deltas to the master variables  
	pass  
