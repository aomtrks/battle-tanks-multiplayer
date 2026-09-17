# Vindex: UDP Multiplayer Battle Game

A fast-paced, real-time local multiplayer tank battle game built with **Flutter** and the **Flame Engine**. 

Unlike standard mobile games relying on BaaS or heavy WebSocket servers, this project implements a completely custom **Host-Client networking architecture using Raw UDP Datagram Sockets**. It features zero-cost custom canvas rendering, lag-compensated physics, and multiple highly competitive game modes.

---

## Key Features

*   **Real-Time LAN Multiplayer:** Seamless UDP-based networking for extremely low latency.
*   **Host-Client Architecture:** The room creator acts as the authoritative server (handling loot spawns, round transitions, and scorekeeping) while clients relay inputs.
*   **Smooth Interpolation:** Movement and rotation use `Vector2.lerp` to mask network latency and packet loss, ensuring buttery-smooth gameplay.
*   **Custom Geometric Rendering:** Zero reliance on heavy image assets. Tanks, bullets, and UI are drawn directly on the Canvas, preventing garbage collection stutters and keeping the game at a locked 60 FPS.
*   **Customizable HUD:** Players can drag and drop the Joystick and Fire Button to fit their ergonomic preferences, saved directly in the game state.

---

## Game Modes

The game features 6 distinct game modes, ranging from casual deathmatches to highly tactical team-based objectives:

1.  ** Classic Maze:** A standard timed deathmatch in a labyrinth.
2.  ** Desert Arena:** An open map with destructible covers. Ammo is limited, requiring players to fight over weighted loot drops.
3.  ** Ice Map:** Features modified physics. Tanks experience inertia and drifting, making movement slippery and unpredictable.
4.  ** Arena (Survival):** A hardcore, round-based mode. Players have 1 HP, bullets ricochet off walls up to 3 times, and friendly fire is enabled. Last tank standing wins the round.
5.  ** Football (Team Mode):** A 2v2 or multi-team soccer match. Players push a central ball by catching it and shooting it into the enemy's goal. Features team-based spawning and disabled friendly fire.
6.  ** Turf War (Paint Mode):** A Splatoon-inspired team battle. Tanks paint the ground as they move. Powered by a zero-network-cost, **O(1) time complexity** grid algorithm where the client calculates cell colors locally.

---

## Loot & Power-Ups

During matches, the Host dynamically spawns loot boxes across the map:

*  **Health:** Restores tank HP to maximum.
*  **Ammo:** Grants +10 bullets (Crucial in Desert and Arena modes).
*  **Shield:** Provides 5 seconds of invulnerability.
*  **Homing Missile:** Replaces the next shot. After 2 seconds of flight, it locks onto the nearest tank (including allies!) with an exponentially increasing turn rate, making it nearly impossible to dodge.
*  **Piercing Laser:** Replaces the next shot. Travels at 2x speed and passes directly through solid walls.

---

## Technical Architecture

### Networking (RawDatagramSocket)
The game uses Dart's `RawDatagramSocket` bound to port `4444`. 
*   **Joining:** Clients broadcast their presence, and the Host assigns them to an 8-point randomized spawn pool to ensure fair, distant spawning.
*   **State Syncing:** Instead of flooding the network every frame, clients sync their positional data at a fixed **Tick Rate (20 updates per second)**.
*   **Grace Periods:** 2.5-second synchronization delays are implemented between rounds to prevent packet loss desyncs during loading phases.

### Collision & Physics
Powered by the Flame engine's `CollisionCallbacks`. Bullets utilize AABB (Axis-Aligned Bounding Box) logic to determine the exact face of a wall they hit, allowing for mathematically accurate ricochets by reversing the specific velocity vector (`velocity.x` or `velocity.y`).

---

## Installation & Running

**Prerequisites:**
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (Latest stable version recommended)
*   Two physical devices on the same Wi-Fi network, OR run multiple instances on a desktop (Windows/macOS) for local testing.

**Steps:**
1. Clone the repository:
   ```bash
   git clone [https://github.com/YOUR_USERNAME/perfectum-tanks.git](https://github.com/YOUR_USERNAME/perfectum-tanks.git)
