# Eaglercraft Classroom Server

A classroom-friendly Minecraft server that runs in **GitHub Codespaces** and lets students join from a web browser.

A teacher can fork this repository, start a Codespace, run one command, and share one browser link with the class.

> **Teacher quick start:** Fork → Create Codespace → run `bash startup.sh` → make port **25567 Public** → share the **/js/** link.

---

## What this repository runs

This classroom version intentionally keeps the stack simple:

- **Paper 1.21.11** — the Minecraft gameplay server
- **Velocity** — the proxy students connect through
- **EaglerXServer / EaglerXRewind** — browser-client support
- **ViaVersion / ViaBackwards / ViaRewind** — protocol compatibility
- **EaglerWeb** — serves the browser client from the same Codespaces address

There is **no separate login server and no nLogin password screen**.

Students choose a Minecraft username in the browser client and connect directly to the classroom world.

### Version note

The backend is **Paper 1.21.11**, while the bundled classroom browser client is currently **Eaglercraft 1.12.2**.

The Via* compatibility plugins translate between the older browser client and the newer Paper backend.

---

# Teacher Setup

## 1. Fork the repository

Sign in to GitHub, open this repository, and choose:

**Fork → Create fork**

Students do **not** need GitHub accounts.

---

## 2. Create a Codespace

Inside your fork:

**Code → Codespaces → Create codespace on main**

The included dev-container configuration uses **Java 21** and forwards port **25567**.

---

## 3. Start the classroom server

Open the Codespaces Terminal and run:

```bash
bash startup.sh
```

The script starts:

```text
Student browser
      ↓
Velocity + EaglerXServer     port 25567
      ↓
Paper 1.21.11               port 25565
      ↓
Classroom world
```

On the first launch, the script downloads the latest stable official Paper 1.21.11 runnable server JAR if it is missing.

Wait until Paper prints its normal **Done** message before students join.

---

## 4. Make port 25567 Public

Open the **PORTS** tab in Codespaces.

Find port:

```text
25567   Eaglercraft Classroom Server
```

Right-click it and choose:

**Port Visibility → Public**

Only port **25567** should be public.

Port **25565** is the internal Paper server and should remain private.

> Codespaces can return a forwarded port to Private after a restart, so check port 25567 before class.

---

## 5. Share the student link

Copy the forwarded URL for port 25567.

It will look similar to:

```text
https://your-codespace-name-25567.app.github.dev
```

Add:

```text
/js/
```

The student link is therefore:

```text
https://your-codespace-name-25567.app.github.dev/js/
```

The client is already configured to connect back to the same Codespaces server, so students do **not** need to type an IP address or WebSocket address.

---

# Student Directions

1. Open the link from your teacher.
2. Let Eaglercraft load.
3. Choose your Minecraft username.
4. Open **Multiplayer**.
5. Select **Classroom Server**.
6. Click **Join Server**.
7. You should enter the class world directly.

There is no registration or password step.

### Username rule

Use only letters, numbers, and underscores.

Minecraft usernames must be **3–16 characters** long.

Use the same username each time so your player data stays associated with the same name.

---

# Starting Class Each Day

Open your Codespace and run:

```bash
bash startup.sh
```

Then verify that **25567 is Public** in the PORTS tab.

Share the `/js/` link with students.

---

# Stopping the Server

In the Paper console, type:

```text
stop
```

Do not include a slash.

Paper will save and shut down, and the startup script will stop Velocity as well.

After that, stop the Codespace.

### Do not delete the Codespace unless you mean to

Stopping a Codespace preserves its files.

Deleting a Codespace can remove local world changes or other files that have not been backed up.

---

# Teacher Console Commands

The terminal running `startup.sh` becomes the Paper server console.

Make yourself an operator:

```text
op YourMinecraftUsername
```

Remove operator permissions:

```text
deop YourMinecraftUsername
```

Save the world:

```text
save-all
```

Stop safely:

```text
stop
```

Console commands do **not** use a leading `/`.

---

# Class Size

The default server limit is:

```properties
max-players=20
```

For a larger class, edit:

```text
server/server.properties
```

For example:

```properties
max-players=30
```

Restart the server afterward.

---

# Installing Classroom Plugins

Paper plugins belong in:

```text
server/plugins/
```

For student coding projects, target the **Paper 1.21.11 API**.

The browser client is 1.12.2, so remember that genuinely newer Minecraft blocks, entities, UI, or client-side behavior may not appear correctly through protocol translation even when the backend plugin itself runs successfully.

---

# Ports

| Port | Purpose | Public? |
|---|---|---|
| **25567** | Velocity + Eaglercraft WebSocket + browser website | **Yes** |
| **25565** | Paper gameplay server | No |

Students only need the port **25567** Codespaces URL.

---

# Classroom Security Note

This server uses Eaglercraft-compatible offline-mode connections.

That means there is **no Mojang/Microsoft account authentication and no classroom password system**.

Anyone who knows the live public Codespaces URL could potentially connect and choose a username, including a username another student has used.

For a normal supervised classroom workflow:

- Share the live URL only with your class.
- Keep the Codespace running only when needed.
- Stop the server after class.
- Do not publish the live Codespaces URL publicly.

If stronger identity controls are required, add a classroom-appropriate access-control system deliberately rather than using the removed nLogin/NanoLimbo flow.

---

# Troubleshooting

## Students see a GitHub sign-in page

Port 25567 is still **Private**.

Go to:

**PORTS → 25567 → Port Visibility → Public**

---

## The browser shows HTTP 502

GitHub is forwarding the port, but Velocity is not currently listening on 25567.

Check the Terminal for a startup error.

You can verify with:

```bash
ss -ltnp | grep 25567
```

---

## The browser loads but Classroom Server shows offline

Wait until Paper has fully started and prints **Done**.

Also check the terminal for Paper errors.

---

## An old login/password screen still appears

You are probably running an older checkout or an old Java process.

Stop the existing server, then run:

```bash
git pull
bash startup.sh
```

The current classroom version does **not** include nLogin or NanoLimbo.

If necessary, close and reopen the browser tab after the restart.

---

## Paper reports `NoClassDefFoundError` or `joptsimple/OptionException`

Pull the current repository and restart:

```bash
git pull
bash startup.sh
```

The current script downloads and launches the proper runnable Paper 1.21.11 server JAR automatically.

---

## Student #21 cannot join

Increase `max-players` in:

```text
server/server.properties
```

Then restart.

---

# Files Teachers Will Most Often Edit

```text
server/server.properties
```

World settings, class size, difficulty, game mode, etc.

```text
server/plugins/
```

Paper plugins and student-created server plugins.

```text
velocity/plugins/eaglerxserver/listeners.toml
```

Eaglercraft listener and server-list settings.

```text
velocity/plugins/eaglerweb/web/
```

The student-facing browser client website.

---

# Architecture

```text
Student Chromebook / Laptop
          │
          │ HTTPS + WebSocket
          ▼
 GitHub Codespaces :25567
          │
          ▼
 Velocity + EaglerXServer
          │
          ▼
    Paper 1.21.11 :25565
          │
          ▼
       Class World
```

The JavaScript client automatically creates its WebSocket server address from the same Codespaces URL that served the game page.

That is why the teacher can share one link rather than a separate browser-client link and server address.

---

# Credits

This classroom-ready fork builds on work from the Eaglercraft community and the Paper, Velocity, ViaVersion, ViaBackwards, and ViaRewind projects.

Minecraft is a trademark of Microsoft/Mojang. This repository is not affiliated with or endorsed by Microsoft or Mojang.

Teachers should review their organization's software, network, privacy, and licensing requirements before classroom deployment.
