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
