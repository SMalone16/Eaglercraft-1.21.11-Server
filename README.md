# Eaglercraft Classroom Server

Run a browser-based Minecraft classroom server from GitHub Codespaces.

Students only need a web browser. Teachers run the server from the Codespace terminal, choose which classroom plugins to test, and share one link.

## Teacher quick start

### 1. Fork this repository

Click **Fork** at the top of this GitHub page and create your own copy.

### 2. Create a Codespace

In your fork:

**Code → Codespaces → Create codespace on main**

The repository requests a **4-core / 16 GB** Codespace for smoother classroom play.

### 3. Start the server

In the Codespace terminal, run:

```bash
bash startup.sh
```

The startup script now checks GitHub `main` for safe fast-forward updates **before** displaying the plugin picker. It never resets a branch or overwrites local changes; set `CLASSROOM_AUTO_UPDATE=0` to disable the check.

A **Classroom Plugin Lab** menu will appear.

Use the number keys to turn student plugins on or off, then choose **START SERVER**.

Wait until Paper prints its normal **Done** message.

### 4. Make the classroom port public

Open the **PORTS** tab in Codespaces.

Find:

```text
25567   Eaglercraft Classroom Server
```

Right-click it and choose:

**Port Visibility → Public**

Leave port **25565** private. That is the internal Paper server.

### 5. Share the student link

Copy the public URL for port 25567 and add:

```text
/js/
```

Example:

```text
https://your-codespace-name-25567.app.github.dev/js/
```

Students open that link, choose a Minecraft username, open **Multiplayer**, and join **Classroom Server**.

That's it.

---

## Classroom defaults and operator permissions

PvP is **disabled by default** (`pvp=false` in `server/server.properties`), and **Malone** is preconfigured as a level-4 operator in `server/ops.json` using the standard offline-mode UUID. If an existing world or proxy assigns `Malone` a different UUID, check and correct operator status from the server terminal after login (`op Malone`).

**Security warning:** This server does **not authenticate usernames**. **Anyone with the public classroom link can log in as `Malone` and receive administrator permissions.** Only use this auto-op convenience after securing access and adding account authentication. A public Codespaces port is accessible to people outside school.

To grant another trusted teacher operator permissions after login, type in the **Paper console**:

```text
op YourMinecraftUsername
```

To remove operator permissions:

```text
deop YourMinecraftUsername
```

### TigerCraft startup screen

The production `/js/` page retains the TigerCraft image on screen until the client reports that its main menu has loaded, covering the original Eaglercraft startup logos. The optional boot menu is disabled. An 18-second fallback prevents permanent blocking if the client lacks the callback. The Eaglercraft logos are **masked, not removed from the compiled game**, so a slow/unusual client may still briefly show a built-in screen. The compiled game and `/wasm/` client are unchanged.

## Start class another day

Open the same Codespace and run:

```bash
bash startup.sh
```

The plugin picker remembers the previous session.

Check that port **25567** is still Public, then share the same style of `/js/` link.

## Stop the server safely

In the server terminal, type:

```text
stop
```

Wait for Paper to finish saving before stopping the Codespace.

Do **not** delete the Codespace unless you are okay losing world changes that only exist inside that Codespace.

---

## Classroom plugins

The startup menu can currently load classroom project plugins such as:

- **Lucky Chests**
- **Eagler Soccer**
- **Eagler Zombies Fall 2026**
- **Eaglervators**
- **Eagler Locust Fall 2026**
- **Triple Jump**
- **Eagler Airplane**
- **Huxley's Space**
- **Eagler Trees**
- **Eagler City**

A plugin can be disabled for one session without deleting its saved data.

This makes it easy to test student mods independently when one project is unfinished or causing problems.

---

## If students cannot connect

Check these three things first:

1. Paper has printed **Done** in the terminal.
2. Port **25567** is **Public** in the Codespaces PORTS tab.
3. Students are using the URL ending in **/js/**.

If the server feels slow, see [Technical setup and performance](docs/TECHNICAL.md).

---

## What runs underneath

```text
Student browser
      ↓
Velocity + EaglerXServer
      ↓
Paper 1.21.11
      ↓
Classroom world + selected student plugins
```

The compatibility stack is installed and verified automatically by `startup.sh`. Teachers do not need to manually install server JARs or configure protocol plugins.

For maintainers, plugin authors, profiling, version pins, and world pre-generation, see:

**[docs/TECHNICAL.md](docs/TECHNICAL.md)**

---

### Classroom note

This setup uses classroom-style usernames rather than Microsoft account authentication. Treat the public Codespaces URL like a classroom invite link and only share it with the people who should be joining your server.

## Undercity integration (optional)
Choose **u) UNDERCITY preset** at the classroom plugin selector to enable just **EaglerCity, EaglerZombiesFall26, LuckyChests, and Eaglervators** together. For noninteractive startup, set `CLASSROOM_PLUGINS=undercity` (or use the comma-separated names `city,zombies,luckychests,eaglervators`). Individual plugin selections and all existing server functionality remain independent.

- **City** excavates a 40×30×20 cavern with its ceiling ten blocks below the town floor, builds a protected 16×16×16 stepped temple with four spawner rooms, a locked loot chamber, exterior shrines, and elevated torch-lit walkways. It persists cavern coordinates to the world PDC; existing city cottages are not rebuilt.
- **Zombies** activates the six matching cavern spawners. Zombie bites trigger a seven-second action-bar timer. Antidote splash potions prevent infection or restore infected teammates, with ten seconds of nonstacking immunity. Infected players can melee-infect, but cannot manipulate items, doors, chests, or the world.
- **Lucky Chests** supplies antidotes in Good/Awesome chests and the ultimate chest's one-time 50/50 award: the complete enchanted Awesome item set or a single Creative Elixir. Only the drinker and players inside the room gain Creative Mode; it ends after two minutes (configurable) or on logout.
- **Eaglervators** provides a city/Undercity up-and-down bubble lift facing the temple entrance, while retaining standalone cliff elevator behavior.

**Important:** The Eaglercraft 1.12.2 client does not support guaranteed server-side player skin substitution. Infection instead uses a following zombie avatar and invisible player, preserving armor/held items. Its local inventory screen may still open, but edits are blocked by the server. Verify water-column movement, door mechanics, and client visuals in-game after deployment. The underground cavern can alter existing terrain and should first be tested in a backup of the classroom world. Plugin runtime JARs are published to each plugin repo's `dist/` folder by their GitHub Actions **after merges to main**.

### Existing Codespace missing the Undercity option?

A GitHub merge does **not** automatically update a Codespace that is already open. If your menu has no `u) UNDERCITY` entry, safely stop Paper (`stop` in its console), then run these commands in the **Codespace terminal in the server repository**:

```bash
git status --short
git pull --ff-only origin main
bash startup.sh
```

If the pull refuses because files are modified, do not use `git reset --hard` or delete the Codespace. Preserve its world and local edits first. Once the updated `startup.sh` has been pulled, future server starts will check for a safe fast-forward automatically. At the interactive menu press **u**, confirm all four mods are marked `[x]`, then press **s** to start; only selected plugins are installed. For a noninteractive terminal, run `CLASSROOM_PLUGINS=undercity bash startup.sh`. Existing world data is not synchronized to GitHub by this update; take a separate backup before allowing Undercity generation.

If the plugin selector says `NOT BUILT / UNAVAILABLE`, that indicates a download/build availability problem; inspect the URL printed by the selector rather than continuing with an incomplete set.

---

### Students cannot reach diamond depth?

Paper already generates the full modern Overworld down to Y=-64, but the
stable Eaglercraft 1.12.2 browser client at `/js/` cannot see the negative-Y
layers. **TuffXPlus alone does not fix the standard client.**

The server now offers an isolated **TuffClient full-depth mining test** at
`/tuff/`, with an automatic installer on startup. Open your Codespaces URL
without `/js/`, choose the TuffClient link once it is available, and select
**TigerCraft (full-depth mining)** in the multiplayer server list. The stable
classroom client, all existing worlds, and student inventories remain
untouched. Mine around Y=-58/-59 to test for diamonds.

This is an *experimental classroom client*, not a verified production
replacement. See [Full-depth mining](docs/TECHNICAL.md#full-depth-mining-for-112-browser-clients)
for validation and troubleshooting instructions.

### Black void, missing blocks, or phantom mobs?

A mob visible in empty black space may indicate a **chunk rendering problem**
rather than a mob-spawning failure. The latest stable ViaVersion and
ViaBackwards fixes are available in the terrain-mapping diagnostic branch;
these fixes are not a guaranteed cure for TuffClient's negative-Y behavior.

In the live Codespace, run `bash scripts/diagnose-world-mapping.sh` to check
installed versions, TuffXPlus's generated Y0 config, saved region presence, and
recent chunk errors **without editing the world**. Compare the same locations
in `/tuff/` and a native Java 1.21.11 client before touching chunk data.
See [technical diagnostics](docs/TECHNICAL.md#missing-terrain-black-void-and-below-y0-verification).
