# Eaglercraft Classroom Server

A classroom-friendly Minecraft server that can run entirely in **GitHub Codespaces**.

A teacher can fork this repository, launch a Codespace, start the server, and share one browser link with students. Students do **not** need Minecraft installed.

> **Teacher quick start:** Fork → Create Codespace → run `bash startup.sh` → make port **25567 Public** → share the **/js/** link.

---

## What this repository runs

This project combines:

- **Paper 1.21.11** — the main Minecraft gameplay server
- **Velocity** — the proxy that students connect through
- **EaglerXServer / EaglerXRewind** — browser-client support
- **ViaVersion / ViaBackwards / ViaRewind** — version compatibility
- **NanoLimbo + nLogin** — temporary login/authentication layer
- **EaglerWeb** — hosts the browser client from the same address as the server

### Important version note

The **server backend is Minecraft/Paper 1.21.11**, but the bundled classroom browser client is currently an **Eaglercraft 1.12.2 client**.

That is intentional. The compatibility plugins translate between the browser client and the newer server backend.

---

# Teacher Setup

## 1. Create a GitHub account

Go to [github.com](https://github.com/) and create a free account if you do not already have one.

Students do **not** need GitHub accounts to play.

## 2. Fork this repository

Open this repository on GitHub.

Click:

**Fork → Create fork**

This gives you your own copy of the server.

You should run the server from **your fork**, not directly from someone else's repository.

---

## 3. Create a Codespace

Inside your fork:

**Code → Codespaces → Create codespace on main**

GitHub will open a browser-based VS Code environment.

This repository includes a `.devcontainer/devcontainer.json` configuration that requests **Java 21** and forwards the Eaglercraft port automatically.

---

## 4. Start the server

Open the **Terminal** at the bottom of Codespaces.

Run:

```bash
bash startup.sh
```

The script starts three pieces of the server:

```text
Students
   ↓
Velocity + EaglerXServer       port 25567
   ↓
NanoLimbo login server        port 25566
   ↓
Paper 1.21.11 world server    port 25565
```

On the first launch, the script also downloads the current NanoLimbo server JAR if it is missing.

Wait until Paper finishes starting and the terminal settles into normal server messages.

---

## 5. Make port 25567 Public

In Codespaces, click the **PORTS** tab next to the Terminal.

You should see:

```text
25567   Eaglercraft Classroom Server
```

Right-click port **25567** and choose:

**Port Visibility → Public**

This is required so student devices can reach the server.

> GitHub forwarded ports are private by default. After restarting a Codespace, always check that **25567 is Public** before class.

Do **not** make ports 25565 or 25566 public. Students only need 25567.

---

## 6. Get the student link

In the PORTS tab, copy the forwarded address for port **25567**.

It will look similar to:

```text
https://your-codespace-name-25567.app.github.dev
```

For students, add:

```text
/js/
```

So the final student link looks like:

```text
https://your-codespace-name-25567.app.github.dev/js/
```

You can test it yourself in a new browser tab before sharing it.

The repository also has a landing page at the base URL where you can choose between the JavaScript and WASM clients.

### Recommended classroom link

Use the **JavaScript client**:

```text
https://YOUR-CODESPACE-25567.app.github.dev/js/
```

It is the default classroom option.

---

# Student Directions

Your teacher will give you a link.

1. Open the link in Chrome, Edge, or another modern browser.
2. Let the Eaglercraft client load.
3. Choose your Minecraft username.
4. Open **Multiplayer**.
5. Select **Classroom Server**.
6. Click **Join Server**.
7. If the server asks you to register or log in, follow the instructions shown in Minecraft chat.
8. Enter the world.

The server address is already built into the client. Students should **not need to type an IP address or WebSocket address manually**.

### Username rule

Minecraft usernames should contain only letters, numbers, and underscores and should be **3–16 characters** long.

Use the same username every time you return to the class server.

---

# Starting Class Each Day

Open the Codespace for your fork and run:

```bash
bash startup.sh
```

Then check the **PORTS** tab and confirm that **25567 is Public**.

Share the same newly displayed `/js/` link with students.

The forwarded Codespaces URL normally remains associated with that Codespace, but teachers should still verify the link before class.

---

# Stopping the Server

When class is finished, type this into the Minecraft server console:

```text
stop
```

Do not include a slash.

The startup script will then stop the supporting proxy/login processes as well.

After the server shuts down cleanly, you can stop the Codespace.

### Important

**Stopping** a Codespace is different from **deleting** it.

Stopping it preserves the Codespace so you can resume later.

Deleting the Codespace can remove server files and world changes that have not been backed up or committed.

---

# Teacher Server Commands

When `startup.sh` is running, the terminal becomes the Paper server console.

To make yourself an operator:

```text
op YourMinecraftUsername
```

To remove operator permissions:

```text
deop YourMinecraftUsername
```

To save the world:

```text
save-all
```

To shut down safely:

```text
stop
```

Console commands do **not** use a leading `/`.

---

# Class Size

The default Paper configuration currently allows:

```text
20 players
```

For a larger class, open:

```text
server/server.properties
```

Find:

```properties
max-players=20
```

and change the number to your desired class capacity, for example:

```properties
max-players=30
```

Restart the server after changing it.

---

# Installing Classroom Plugins

Paper plugins belong in:

```text
server/plugins/
```

Most Paper/Spigot plugins are distributed as `.jar` files.

After adding a plugin, restart the server.

For student coding projects, the backend students are targeting is **Paper 1.21.11**, even though the supplied browser client is based on Eaglercraft 1.12.2.

This makes it possible to use a modern Paper plugin API while keeping a browser-based student client.

---

# Which Port Does What?

| Port | Purpose | Make Public? |
|---|---|---|
| **25567** | Velocity + Eaglercraft WebSocket + browser website | **Yes** |
| **25566** | NanoLimbo authentication server | No |
| **25565** | Paper gameplay server | No |

Students should only ever be given the **25567 Codespaces URL**.

---

# Troubleshooting

## Students see a GitHub sign-in page

Port 25567 is still **Private**.

Go to:

**PORTS → 25567 → Port Visibility → Public**

Then reload the student link.

---

## The browser says the page cannot be reached

Check that:

- `bash startup.sh` is still running.
- Port **25567** appears in the PORTS tab.
- Port **25567** is set to **Public**.
- You copied the current Codespaces URL.
- You added `/js/` to the end of the student link.

---

## The game loads but Classroom Server is offline

Wait until the Paper server has completely started.

Also make sure the terminal does not show a crash or Java error.

---

## The startup script says Java is missing

The included Codespaces configuration uses Java 21.

If you created the Codespace **before** this repository gained its `.devcontainer` configuration, rebuild the container or create a fresh Codespace from the current repository.

---

## Students cannot join after a Codespace restart

Check the PORTS tab again.

GitHub may return a forwarded port to **Private** visibility after a Codespace restart. Set **25567** back to **Public**.

---

## Student #21 cannot join

The default maximum is 20 players.

Increase `max-players` in:

```text
server/server.properties
```

Then restart the server.

---

## A student is stuck on the login screen

The server uses nLogin/NanoLimbo before moving students into the Paper world.

Have the student follow the registration/login instructions displayed in Minecraft chat and make sure they are using the same username they previously registered.

---

# Files Teachers Will Most Often Edit

```text
server/server.properties
```

World settings, player limit, difficulty, game mode, etc.

```text
server/plugins/
```

Paper plugins and student-created server plugins.

```text
velocity/plugins/eaglerxserver/listeners.toml
```

Eaglercraft server-list name/MOTD and listener options.

```text
velocity/plugins/eaglerweb/web/
```

The student-facing browser client website.

---

# Classroom Safety / Network Notes

The browser client in this fork is hosted directly by the teacher's Codespace.

The classroom landing page included in this fork has been cleaned so it does **not** load the third-party advertising script that was present in the upstream template.

Port 25567 must be Public for students to connect, which means anyone who has that URL can reach the server while the Codespace is running.

For a classroom server:

- Share the link only with the class.
- Stop the server when class is over.
- Use a whitelist or authentication controls if you need stricter access.
- Do not publish the live Codespaces URL publicly.

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
          ├──────────────► NanoLimbo :25566
          │                   login
          │
          ▼
     Paper 1.21.11 :25565
          │
          ▼
       Class World
```

The JavaScript Eaglercraft client automatically builds its WebSocket server address from the same Codespaces URL that loaded the webpage.

That is why the teacher can share **one link** instead of giving students a separate game-client link and server IP.

---

# Credits

This classroom-ready fork builds on the Eaglercraft server work by the Eaglercraft community, including EaglerXServer/EaglerXRewind, Paper, Velocity, ViaVersion, ViaBackwards, ViaRewind, NanoLimbo, nLogin, and the original server template authors.

Minecraft is a trademark of Microsoft/Mojang. This repository is not affiliated with or endorsed by Microsoft or Mojang.

Teachers should review their organization's software, network, privacy, and licensing requirements before classroom deployment.
