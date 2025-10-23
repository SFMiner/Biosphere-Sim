# **Game Design Document: Biosphere Jar**

### **Table of Contents**

1. **Overview**  
   * 1.1 Game Concept  
   * 1.2 Audience & Educational Goals  
   * 1.3 Platform & Distribution  
   * 1.4 Development Team  
2. **Core Gameplay Loop**  
   * 2.1 Setup Phase  
   * 2.2 Simulation Phase  
3. **Core Mechanics: The Simulation Engine**  
   * 3.1 Resource Pools  
   * 3.2 Species Data Structure  
   * 3.3 Simulation Cycle Logic  
   * 3.4 Tank Size & Scale  
4. **Player Interaction & Controls**  
   * 4.1 Time Controls  
   * 4.2 Camera Controls  
   * 4.3 Environment Controls  
   * 4.4 Setup Phase Controls  
   * 4.5 Taking Pictures  
5. **Game Modes & Features**  
   * 5.1 Game Modes (Sandbox, Beginner)  
   * 5.2 Challenges  
   * 5.3 Educational Popups  
6. **UI / UX (User Interface & Experience)**  
   * 6.1 Main HUD Layout  
   * 6.2 Setup Phase Toolbox  
   * 6.3 Special Screens (Loading, Photo Album)  
7. **Art & Audio**  
   * 7.1 Visual Style  
   * 7.2 Audio Design  
8. **Technical Overview**  
   * 8.1 Engine  
   * 8.2 Core Architecture

## **1\. Overview**

### **1.1 Game Concept**

**Biosphere Jar** is a 2D sandbox simulation where players create and manage a miniature sealed ecosystem in a virtual jar. Players add various species of plants, invertebrates, and microorganisms, set initial environmental conditions, and then seal the jar. The core of the game is observing the emergent behavior of the ecosystem as populations rise and fall based on a complex, abstract model of biological and chemical cycles.

### **1.2 Audience & Educational Goals**

* **Primary Audience:** Middle elementary and middle school students (Ages 9-14).  
* **Educational Goals:**  
  * To introduce the core concepts of a biosphere: producers, consumers, and decomposers.  
  * To visualize abstract cycles like the oxygen/CO2 cycle and the nitrogen cycle.  
  * To demonstrate how predator-prey relationships and resource scarcity create population dynamics.  
  * To allow safe, consequence-free experimentation without harming living organisms.

### **1.3 Platform & Distribution**

* **Platform:** HTML5 for browser-based play.  
* **Distribution:** Free to play, hosted on a personal website for educational use.

### **1.4 Development Team**

* **Primary:** One human developer/artist.  
* **Support:** AI agents for brainstorming, code generation, and content creation.

## **2\. Core Gameplay Loop**

The game is divided into two distinct phases.

### **2.1 Setup Phase**

The player begins with an empty container. In this phase, they act as the creator, using a "Toolbox" UI to populate their biosphere.

1. **Choose Container:** Select a container size (e.g., "1L Mason Jar," "10 Gallon Tank").  
2. **Add Organisms:** Add species in discrete "units" (e.g., "1 Snail," "Batch of 20 Daphnia"). Each unit adds a predefined amount of abstract biomass to the simulation.  
3. **Set Initial Conditions:** The player can add initial amounts of nutrient\_pool, soft\_detritus, or hard\_detritus (e.g., adding "Driftwood" or "Peat").  
4. **Seal the Jar:** Once satisfied, the player clicks a button to "Seal" the jar, which begins the Simulation Phase.

### **2.2 Simulation Phase**

The Setup Toolbox is locked away. The ecosystem is now a closed system, and the player's role shifts from creator to observer and external influencer.

1. **Observe:** The simulation runs, and the player watches the populations and resource levels change over time.  
2. **Influence:** The player's only direct controls are over external environmental factors: **Light Intensity** and **Temperature**.  
3. **Learn:** The player can click on elements to bring up educational popups explaining what they are and their role in the ecosystem.  
4. **Document:** The player can take screenshots to document interesting states of their biosphere.

## **3\. Core Mechanics: The Simulation Engine**

The simulation is not agent-based. It is a system of interconnected resource pools and abstract population densities, calculated per frame. All logic is handled by a central EcosystemManager script.

### **3.1 Resource Pools**

These global variables represent the chemical state of the biosphere.

* oxygen (float): Gaseous oxygen available.  
* co2 (float): Gaseous carbon dioxide available.  
* nutrient\_pool (float): "Good" dissolved nitrogen (nitrates) usable by producers.  
* soft\_detritus (float): Fast-decaying organic matter (soft tissues, feces) that quickly breaks down and releases nitrogen, potentially causing ammonia spikes.  
* hard\_detritus (float): Slow-decaying organic matter (wood, shells, chitin) that acts as a long-term reservoir of carbon and minerals, breaking down very slowly.  
* toxic\_waste (float): "Bad" dissolved nitrogen (ammonia) from excretion and the rapid decay of soft\_detritus, which is harmful at high concentrations.

### **3.2 Species Data Structure**

All species data is stored in flexible Dictionaries, allowing for easy modification and expansion.

* populations: A dictionary storing the current abstract biomass of each species.  
  * {"algae": 100.0, "daphnia": 25.4, "snail": 15.0}  
* species\_params: A dictionary defining the metabolic properties and setup units for each species. Upon death, their biomass is split between soft and hard detritus.  
  * {"snail": {"unit\_biomass": 15.0, "soft\_biomass": 5.0, "hard\_biomass": 10.0, "respiration": 0.01, "death": 0.02, "waste": 0.03, "toxicity\_sensitivity": 0.2}}  
* food\_web: A nested dictionary defining who eats whom and the interaction rate.  
  * {"hydra": {"daphnia": 0.01, "cyclops": 0.008}}

### **3.3 Simulation Cycle Logic**

The simulation logic is executed in a specific order within a single function, advance\_simulation(delta).

1. **Producers (Photosynthesis):** Algae and other producers consume co2 and nutrient\_pool to grow, producing oxygen. Growth is limited by the least available resource (light, CO2, or nutrients).  
2. **Decomposers (Recycling):** Bacteria primarily consume soft\_detritus, converting it into toxic\_waste. They also consume toxic\_waste and convert it into nutrient\_pool. This is the core of the nitrogen cycle.  
3. **Hard Detritus Decay:** A very slow, passive process where hard\_detritus breaks down into soft\_detritus or directly into nutrient\_pool, releasing its stored mass into the system over a long period.  
4. **Consumers (Predation):** The food\_web dictionary is parsed. For each predator, food intake is calculated based on its own density, the density of its prey, and the interaction rate. Prey biomass is reduced, and predator biomass increases (with an energy transfer efficiency loss).  
5. **Metabolism (Respiration, Waste, Death):** A final loop iterates through *all* species. Each species consumes oxygen, produces co2 (respiration), and excretes toxic\_waste. When an organism dies, its soft\_biomass is added to the soft\_detritus pool and its hard\_biomass is added to the hard\_detritus pool.  
6. **Toxicity Feedback:** High levels of toxic\_waste will increase the death rate for all organisms based on their individual toxicity\_sensitivity.

### **3.4 Tank Size & Scale**

The selected container size (tank\_volume) acts as a global scalar. It primarily affects the "dilution" of waste. The total capacity of resource pools and the impact of waste events are scaled by this volume. A dead fish in a 1L jar will cause a catastrophic ammonia spike, while in a 10-gallon tank, it will be a minor event.

## **4\. Player Interaction & Controls**

### **4.1 Time Controls**

A persistent UI element will provide standard playback controls.

* **Play/Pause:** Sets Engine.time\_scale to 1.0 or 0.0.  
* **Fast-Forward:** Buttons for 2x, 4x, and 8x speed, modifying Engine.time\_scale.  
* **Skip Ahead:** Buttons for "Skip 1 Day" or "Skip 1 Week." This triggers a "headless" simulation that runs the advance\_simulation() function in a fast loop without rendering graphics, showing a "Simulating..." overlay until complete.

### **4.2 Camera Controls**

* **Zoom:** The mouse wheel will control the Camera2D zoom level, allowing players to get a close-up look at the organisms or a wide view of the whole tank.  
* **Pan:** (Optional) Click-and-drag with the middle or right mouse button to pan the camera view.

### **4.3 Environment Controls**

During the Simulation Phase, the player has two sliders available in the main UI.

* **Light Intensity:** A slider from "Dark" to "Bright Sun" (0.0 to 2.0).  
* **Temperature:** A slider controlling the water temperature (e.g., 15°C to 30°C).

### **4.4 Setup Phase Controls**

The "Toolbox" UI will feature a list of available organisms. Each organism has a \[+\] and \[-\] button to add or remove one "unit" at a time, with text clarifying the unit (e.g., "Add 1 Snail," "Add Batch of 20 Daphnia").

### **4.5 Taking Pictures**

A camera icon in the UI allows the player to save a .png screenshot of the current viewport to their local device. A "Photo Album" screen will be accessible from the main menu to view saved pictures.

## **5\. Game Modes & Features**

### **5.1 Game Modes**

* **Sandbox Mode:** The default mode. All species and container sizes are unlocked from the start. Simulation parameters are at their default difficulty.  
* **Beginner Mode:** A toggleable option.  
  * The list of available species in the Setup Phase is limited to simpler, more robust organisms (e.g., no fish).  
  * Hazardous effects, like toxicity\_factor, are reduced (e.g., by 50%) to make balancing the first ecosystem more forgiving.

### **5.2 Challenges**

A separate game mode that presents the player with a specific goal and starting conditions.

* *Example 1: "Fish in a Jar"* \- Can you establish a self-sustaining population of Endler's Livebearers in the smallest possible container?  
* *Example 2: "Cleanup Crew"* \- Start with a tank full of soft\_detritus and toxic\_waste. Add the right combination of decomposers to make it habitable.

### **5.3 Educational Popups**

Clicking on any organism sprite or a UI label (e.g., the "Toxic Waste" meter) will pause the game and open a modal window with a brief, easy-to-understand explanation of that element's role in the ecosystem.

## **6\. UI / UX (User Interface & Experience)**

### **6.1 Main HUD Layout**

The screen is dominated by the visual of the jar/tank. UI elements are arranged around it.

* **Top/Bottom:** A persistent bar with Time Controls (Play/Pause/FF/Skip) and the Screenshot button.  
* **Left Side:** A vertical panel displaying the primary Resource Pool levels (Oxygen, CO2, Nutrients, Toxic Waste, etc.) with clear labels and bars.  
* **Right Side:** A vertical panel with the sliders for Light Intensity and Temperature.

### **6.2 Setup Phase Toolbox**

During the Setup Phase, the right-side panel is replaced with a scrollable "Toolbox" menu showing all available species, their icons, and their respective \[+\] and \[-\] buttons.

### **6.3 Special Screens**

* **Loading Screen:** A simple overlay with a "Simulating..." message and a spinner icon that appears during a "Skip Ahead" operation.  
* **Photo Album:** A grid-based gallery that displays saved screenshots.

## **7\. Art & Audio**

### **7.1 Visual Style**

* **Aesthetic:** Clean, 2D vector, or high-quality cartoon style. The look should be inviting and clear, not gritty or hyper-realistic.  
* **Animation:** Organisms will have simple, looping animations (e.g., wiggling, floating) to make the scene feel alive.  
* **Color Palette:** Bright and appealing, with clear visual feedback (e.g., water becomes slightly brown/murky as soft\_detritus increases).

### **7.2 Audio Design**

* **Music:** A single, calm, ambient background track that is not distracting (lo-fi or minimalist).  
* **Sound Effects (SFX):** Subtle and satisfying.  
  * A soft "plip" when adding an organism.  
  * UI clicks and slider movements.  
  * A gentle "alert" sound if a resource pool reaches a critical level.

## **8\. Technical Overview**

### **8.1 Engine**

* Godot Engine (Version 4.x).

### **8.2 Core Architecture**

* A main scene containing the EcosystemManager node, which holds all data and runs the advance\_simulation() logic.  
* Visual organism nodes are spawned and despawned dynamically by a PopulationVisualizer script that reads from the EcosystemManager's populations dictionary but is not part of the simulation logic itself.  
* The UI is built using Godot's Control nodes in a separate scene tree.  
* The "Skip Ahead" feature will use an async function to run the simulation loop without freezing the application.