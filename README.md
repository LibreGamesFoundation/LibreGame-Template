# LibreGame Template

[![Discord](https://img.shields.io/badge/Discord-Join%20-5865F2?logo=discord&logoColor=white)](https://discord.gg/EhUVN3Q2UG)
[![Godot](https://img.shields.io/badge/Godot-v4.7.2%20-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org/download/)
[![MIT LICENSE](https://img.shields.io/badge/License-MIT%20-aa0000?logo=MIT&logoColor=white)](LICENSE)

Template for 2D and 3D Godot projects, built to be forked for bigger projects.


## Features

### Components
|  Class Name   | Icon |  Description  | Extends From |
| ------------- | :-------------: | -------------- | -------------- |
| ComponentBase |![](assets/components/ComponentNode.svg)|Base class for all Components that exist outside of 2D or 3D space | Node |
| Component2D |![](assets/components/Component2DNode.svg)|Base class for all Components that exist within 2D space | Node2D |
| Component3D |![](assets/components/Component3DNode.svg)|Base class for all Components that exist within 3D space | Node3D |
| AnalogCaptureComponent |![](assets/components/AnalogCaptureComponentNode.svg)|Used for getting mouse and joystick movement | ComponentBase |
| Hitbox2D |![](assets/components/Hitbox2DNode.svg)|Deals damage to any Hurtbox2D it overlaps | Area2D |
| Hitbox3D |![](assets/components/Hitbox3DNode.svg)|Deals damage to any Hurtbox3D it overlaps | Area3D |
| Hurtbox2D |![](assets/components/Hurtbox2DNode.svg)|Receives hits from any Hitbox2D it overlaps and forwards damage to a target | Area2D |
| Hurtbox3D |![](assets/components/Hurtbox3DNode.svg)|Receives hits from any Hitbox3D it overlaps and forwards damage to a target | Area3D |
| InventoryComponent |![](assets/components/InventoryComponentNode.svg)|Component for storing and managing a collection of stackable items | ComponentBase |
| ResourceComponent |![](assets/components/ResourceComponentNode.svg)|Component for creating and managing any type of singular resource | ComponentBase |
| StateMachine |![](assets/components/ComponentNode.svg)|Manages State Nodes | ComponentBase |
| State |![](assets/components/ComponentNode.svg)|Base class for all States. Designed to be used with StateMachine Node | ComponentBase |

### Resources
| Resource Name | Description  | Extends From |
| ------------- | :-------------: | -------------- |
| InventoryItem | Base resource describing a stackable inventory item | Resource |

## Contributions
If you find any issues or bugs feel free to create an issue or a Pull Request.
