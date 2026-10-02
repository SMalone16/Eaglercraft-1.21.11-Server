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

## Become a server operator

After you join the world, type this in the server terminal:

```text
op YourMinecraftUsername
```

You now have teacher/admin permissions.

To remove operator permissions:

```text
deop YourMinecraftUsername
```

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
- **Eagler Locust Fall 2026**

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
