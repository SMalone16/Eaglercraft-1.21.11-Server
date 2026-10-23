# Technical Setup and Performance

This document is for maintainers, plugin authors, and teachers troubleshooting performance.

The main README intentionally stays short.

## Current server architecture

```text
Browser client
    │
    │ HTTPS / WebSocket through Codespaces port 25567
    ▼
Velocity 3.5
    ├─ EaglerXServer 1.1.1
    ├─ EaglerWeb 1.1.1
    └─ EaglerXRewind 1.1.1
    │
    │ localhost:25565
    │ uncompressed backend connection
    ▼
Paper 1.21.11
    ├─ ViaVersion 5.12.0
    ├─ ViaBackwards 5.12.0
    ├─ ViaRewind 4.2.0
    ├─ TuffXPlus 1.1.1
    └─ selected classroom plugins
```

The production browser client remains the known-good Eaglercraft 1.12.2 build under `/js/`.

Additional client slots are isolated:

- `/js/` — production browser client
- `/wasm/` — alternate production client
- `/modern/` — staging slot
- `/experimental/1.21/` — experimental modern-client slot

## Why the stack is split

Velocity handles the browser-facing Eagler connection.

Paper handles gameplay and the world.

ViaVersion / ViaBackwards / ViaRewind translate protocol differences between the older browser client and the modern Paper backend.

TuffXPlus adds modern block, entity, and below-Y0 compatibility. Its upstream requirements are ViaVersion and ViaBackwards on the backend server; it does not require ProtocolLib or TAB.

## Managed dependency model

Core runtime JARs are not manually maintained in the repository.

Pinned versions, URLs, and SHA-256 checksums live in:

```text
stack-versions.env
```

At startup:

```text
scripts/install-managed-dependencies.sh
```

downloads missing managed JARs and verifies them before launch.

The smoke test then checks the expected topology:

```text
scripts/stack-smoke-test.sh
```

## Classroom project plugins

Student plugins are controlled separately from the compatibility stack.

The catalog is:

```text
classroom/plugins.conf
```

The startup picker:

```text
scripts/select-classroom-plugins.sh
```

downloads only the selected project JARs for that session.

Runtime names use:

```text
server/plugins/classroom-session-*.jar
```

Plugin data folders are preserved when a project is disabled.

### Add another classroom project

Add one line to `classroom/plugins.conf` using the existing format:

```text
id|Display Name|owner/repository|branch|path/to/plugin.jar|default-enabled|legacy-prefix
```

The project repository should publish a compiled Paper JAR at the configured path.

## Performance defaults

### Codespaces machine

The devcontainer requests:

```text
4 CPU cores
16 GB RAM
32 GB storage
```

Minecraft server performance depends heavily on single-thread CPU availability. A 2-core Codespace can run the stack, but it has much less headroom when Paper, Velocity, protocol translation, chunk generation, and classroom plugins are active together.

### JVM memory

`startup.sh` automatically chooses a memory budget based on host RAM.

On a 16 GB host the defaults are approximately:

```text
Paper:    Xms 4 GB / Xmx 8 GB
Velocity: Xms 256 MB / Xmx 768 MB
```

On smaller existing Codespaces it falls back to a safer lower-memory profile.

Both can be overridden with environment variables:

```bash
PAPER_JAVA_OPTS="..." VELOCITY_JAVA_OPTS="..." bash startup.sh
```

### Network compression

Paper and Velocity run on the same machine over localhost.

The Paper backend therefore uses:

```properties
network-compression-threshold=-1
```

This avoids spending CPU compressing packets only for the local proxy to unpack and translate them.

Velocity remains responsible for the external client connection.

EaglerX WebSocket compression is set to level 3 to reduce CPU cost while still compressing browser traffic.

### EaglerX worker count

The Eagler skin-cache worker pool is limited to one thread:

```toml
skin_cache_thread_count = 1
```

This prevents auxiliary skin work from trying to use every available processor on a small Codespace.

### Minecraft distances

The classroom defaults are:

```properties
view-distance=6
simulation-distance=4
```

These are intentionally moderate. Lower them further only if profiling shows chunk/entity simulation is still the limiting factor.

## Profiling lag with Spark

Modern Paper includes Spark.

When the server is lagging during normal classroom activity, run from the server console:

```text
spark profiler start --timeout 600
```

For intermittent severe ticks:

```text
spark profiler start --only-ticks-over 100 --timeout 300
```

Let students play normally while the profiler runs.

Use the generated Spark report to identify whether time is being spent in:

- chunk generation
- entity AI
- a classroom plugin
- Via/TuffX translation
- world saving
- another server subsystem

Profile before applying aggressive gameplay-changing optimizations.

## World pre-generation

Exploration can cause major lag because new chunks require terrain generation, structures, lighting, entities, compatibility translation, and sometimes classroom-plugin generation hooks.

For a long-running classroom world, pre-generating the playable area before students explore it can help substantially.

A common Paper tool for this is the official **Chunky** pre-generator:

https://hangar.papermc.io/pop4959/Chunky

Install the Paper plugin, restart the server, then use the server console.

Example for a 2,000-block radius around 0,0:

```text
chunky world world
chunky center 0 0
chunky radius 2000
chunky start
```

Run pre-generation before class rather than while students are actively playing.

Do not automatically pre-generate enormous worlds. Generated chunks consume persistent disk space.

## Intentional plugin cleanup

The core server no longer includes committed copies of:

```text
ProtocolLib
TAB
```

Neither is required by the documented Eagler/TuffX compatibility stack.

If a future classroom plugin genuinely requires one, add it deliberately as a managed dependency rather than dropping an unexplained JAR into `server/plugins/`.

## Important files

```text
startup.sh
    Main teacher launch command.

.devcontainer/devcontainer.json
    Codespaces image, forwarded port, and recommended machine resources.

server/server.properties
    Paper networking, view distance, simulation distance, player limit.

server/config/
    Paper global/world configuration.

velocity/velocity.toml
    Velocity proxy configuration.

velocity/plugins/eaglerxserver/
    EaglerXServer runtime configuration.

stack-versions.env
    Pinned versions and checksums for the core compatibility stack.

scripts/install-managed-dependencies.sh
    Downloads and verifies core dependencies.

scripts/select-classroom-plugins.sh
    Interactive classroom project selector.

scripts/stack-smoke-test.sh
    Validates the expected server topology before launch.

classroom/plugins.conf
    Classroom project plugin catalog.

classroom/client-splashes.txt
    Reviewed classroom-safe Minecraft splash text.
```

## Production philosophy

Keep the production path boring.

A teacher should normally only need:

```bash
bash startup.sh
```

Experimental clients, future protocol stacks, aggressive Paper tuning, and new classroom plugins should be tested without replacing the known-good `/js/` path until they are validated.

---

## Full-depth mining for 1.12 browser clients

**Diagnosis:** This Paper 1.21.11 server uses vanilla `level-type=minecraft\\:normal`
terrain, with the Overworld's normal bedrock at approximately Y=-64. Spigot also
sets `below-zero-generation-in-existing-chunks: true`. The world is *not*
intentionally truncated at Y=0. ViaBackwards translates modern worlds for the
stable 1.12.2 browser client, whose renderer cannot show blocks below Y=0.
That includes much of the diamond-rich underground terrain.

TuffXPlus is present in the managed plugin stack, but its below-Y0 feature
is specifically designed for **TuffClient**, not a standard Eaglercraft
1.12.2 build. Merely installing the Paper plugin does not extend the stable
`/js/` client's world height.

### Non-destructive full-depth test

`startup.sh` installs an isolated, pinned official TuffClient 1.1UT15 JS
build under `/tuff/` (about 27 MB, first launch only). The installer verifies
the exact upstream Git blob SHA and adds a **TigerCraft (full-depth mining)**
server-list entry on the same Codespaces origin. It does **not** modify:
- `/js/`, `/wasm/`, or any other existing browser client;
- the Paper world, region files, seed, structures, inventories, or ore blocks;
- ViaVersion, Paper, or TuffXPlus version pins.

From the root Codespaces game URL, choose **Launch Full-Depth TuffClient**,
then choose the TigerCraft entry. It is a *test client* and should first be
checked by an operator before classroom rollout. The world stays the same for
both clients. When functioning correctly, TuffClient + TuffXPlus should show
the existing caves, deepslate, bedrock, and diamond ore down to Y=-64. A good
place to test naturally occurring diamonds is around Y=-58/-59.

If a Codespace has no outbound network access or the checksum verification
fails, `startup.sh` warns and continues running the stable `/js/` client.
Manually retry from the repository root:

```bash
bash scripts/install-tuff-client.sh
```

Set `CLASSROOM_TUFF_AUTO_INSTALL=0` to disable the startup installation check.
When diagnosing missing negative-Y terrain, confirm `/plugins` lists
TuffXPlus; inspect `server/plugins/TuffXPlus/config.yml` for
`y0.y0-enabled: true` and `world` in `y0.enabled-worlds`. Restart Paper
after changing its config, and test from `/tuff/`, not `/js/`.

**Important:** We intentionally do **not** rewrite the world generator to
make bedrock appear at Y=0. That could invalidate old chunks, underground
caves, builds, and the expected ore distribution. Nor does enabling a client
regenerate previously explored chunks: Paper already generates the negative-Y
layers. Make a Codespace/world backup before experimental changes and use
`stop` in the Paper console before stopping the Codespace.

---

## Missing terrain, black void, and below-Y0 verification

A screenshot showing visible mobs in a black void is **not proof of failed mob
spawning**; entities can render while the old client receives incomplete chunk
data. The dimension cannot be established from Y=0 or from nether bricks alone:
zombies and creepers may indicate the Overworld (including a player-built
Undercity), while the vanilla Nether normally starts at Y=0. Confirm the
actual **dimension**, client URL and coordinates before changing any settings.

The original source fork, `lax0dude/Eaglercraft-1.21.11-Server`, last changed
May 16, 2026 and has no newer fix for this problem. Importantly, the source
fork bundles BOTH obsolete `TuffX.jar` and `TuffXPlus-1.0.0.jar`, which the
upstream TuffXPlus maintainer explicitly says **never** to use together.
This classroom repo correctly retains only TuffXPlus and the three Via*
backend plugins.

### Version review, October 23, 2026

| Runtime | Stable version in this change | Finding |
| --- | --- | --- |
| ViaVersion | 5.12.1 | 5.12.0 → 5.12.1, upstream bug fixes; test old-client packet/registry mapping |
| ViaBackwards | 5.12.1 | 5.12.0 → 5.12.1, old-client mappings and entity fixes |
| ViaRewind | 4.2.0 | Already latest stable as inspected; do not change |
| TuffXPlus | 1.1.1 | Latest **stable** release; 1.1.2-beta exists on upstream `builds/`, not auto-enabled |
| EaglerXServer / EaglerWeb / EaglerXRewind | 1.1.1 | Already latest stable as inspected; do not change |
| Paper | 1.21.11 | World generator is already modern; Paper JAR is provisioned on first startup |

Upstream references:
- https://github.com/ViaVersion/ViaVersion/releases/tag/5.12.1
- https://github.com/ViaVersion/ViaBackwards/releases/tag/5.12.1
- https://github.com/TuffNetwork/TuffXPlus/issues/62
- https://github.com/TuffNetwork/TuffXPlus/issues/53
- https://github.com/TuffNetwork/TuffXPlus/tree/main/builds

ViaBackwards may warn that older clients cannot see blocks below Y0. This
warning is expected for **standard** 1.12 clients and *does not alone prove*
that TuffClient's own `eagler:below_y0` handshake is succeeding or failing.

### Check the live Codespace without editing the world

On the **same Codespace running Paper** (not just GitHub's repository view):

```bash
bash scripts/diagnose-world-mapping.sh
```

This reads version pins, locally installed JAR filenames, runtime TuffXPlus
and ViaBackwards settings, saved-region presence, and recent chunk/packet
warnings. It does not load or rewrite chunks. World saves and TuffXPlus's
generated `server/plugins/TuffXPlus/config.yml` are **not tracked by Git**;
their live content cannot be verified from the repository.

Check that:
1. `server/plugins/TuffXPlus/config.yml` has `y0.y0-enabled: true` and the
   actual Overworld name (usually `world`) in `y0.enabled-worlds`; do not
   automatically enable the Nether or End without testing dimension support.
2. `server/plugins/ViaBackwards/config.yml` has
   `bedrock-at-y-0: false`; the synthetic bedrock option can obstruct
   negative-Y gameplay for older clients.
3. The client used for the full-depth test is `/tuff/` and its y0 handshake
   succeeds; `/js/` is the protected stable client, not the full-depth client.
4. Compare the **same chunk coordinates and dimension** in a real 1.21.11
   Java client. If Java sees terrain but TuffClient doesn't, investigate
   TuffXPlus/translation/client chunk handling rather than ore generation.
5. Compare `/tuff/` with `/js/` only as a diagnostic; the latter cannot
   display negative-Y Overworld terrain. Report exact block interactions,
   not just whether mobs look suspended.
6. Upstream TuffXPlus issue #62 documents ongoing ghost blocks / no block
   drops for TuffClient UT15 on some 1.21 servers. This has **not** been
   conclusively fixed in a stable release.

**Do not erase `region/`, create a replacement world, globally shift chunks,
or turn on synthetic Y0 bedrock as a supposed fix.** Stop Paper cleanly
and back up the Codespace's actual world before testing any plugin changes.
The updated Via JAR installer now downloads/checks new JARs before deleting
older working Via copies, reducing the chance of a partial upgrade.

### Testing in a controlled order

1. Create an off-server backup of `server/world*` and `server/plugins/`
   including plugin configurations (avoid distributing player data).
2. Restart with updated ViaVersion/ViaBackwards **5.12.1** and stable
   TuffXPlus **1.1.1**. Check `/plugins` and server console for load errors.
3. Compare identical block positions in a native Java 1.21.11 client and
   `/tuff/`. Check Y=-40 to -59 **in the Overworld** only.
4. If only TuffClient displays void/ghost blocks, keep the known-good
   `/js/` available and collect the diagnostic output plus a small redacted
   log for upstream issue #62. Do not experiment on the only classroom world.
5. If both Java and TuffClient show missing blocks, investigate saved region
   files/world generator or student-plugin terrain edits separately; do not
   infer a packet problem from the screenshot alone.
