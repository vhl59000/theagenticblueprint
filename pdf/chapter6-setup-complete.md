# Chapter 6 (REVISED): OpenClaw Setup — The Complete Guide

*This chapter will have you running a 24/7 AI agent in under 20 minutes.*

The standard path: a Hetzner VPS (€4/month) + OpenClaw + Telegram. This is the setup used by thousands of operators. It's cheap, reliable, and fully under your control.

---

## Part 1: Create Your Hetzner Server

**Step 1 — Go to Hetzner Cloud**
Visit [hetzner.com/cloud](https://hetzner.com/cloud) and click **Get started**. Create an account if you don't have one.

**Step 2 — Create a new project**
Once logged into Cloud Console, click **+ New Project**. Name it `openclaw` or similar.

**Step 3 — Create your server**
Click into your project, then click the big **+ Create Server** button.

**Step 4 — Choose location & type**
- **Location:** Germany (cost-optimized tier)
- **Image:** Ubuntu 24.04
- **Type:** Shared vCPU → **CX22** (2 vCPU, 4GB RAM) — ~€4/mo
- **IPv4:** Keep it ON

**Step 5 — Add your SSH key**

On Mac/Linux — open Terminal and run:
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```
Press Enter to accept defaults. Then display your public key:
```bash
cat ~/.ssh/id_ed25519.pub
```

On Windows (PowerShell):
```powershell
ssh-keygen -t ed25519 -C "your@email.com"
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copy the output and paste it into Hetzner's SSH key field.

**Step 6 — Create the server**
Name your server `openclaw`, then click **Create & Buy Now**. Wait about 30 seconds for it to spin up, then copy the IPv4 address.

---

## Part 2: Connect & Install

**Step 7 — SSH into your server**

Open Terminal (Mac/Linux) or PowerShell (Windows):
```bash
ssh root@YOUR_SERVER_IP
```
Replace `YOUR_SERVER_IP` with the IP you copied. Type `yes` when asked about the fingerprint.

> **SSH asking for password?** Your key isn't being used. Specify it explicitly:
> ```bash
> ssh -i ~/.ssh/id_ed25519 root@YOUR_SERVER_IP
> ```

**Step 8 — Update the system**
```bash
apt update && apt upgrade -y
```

**Step 9 — Install Node.js 22**
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
```
Verify with `node -v` — should show `v22.x.x`

**Step 10 — Install OpenClaw**
```bash
npm install -g openclaw@latest
```

> **Note:** Earlier guides (pre-2026) reference `clawdbot` — OpenClaw is the current name. All `clawdbot` commands map directly to `openclaw`.

**Step 11 — Run the setup wizard**
```bash
openclaw configure
```
This walks you through everything: model auth, workspace setup, and channel configuration.

---

## Part 3: Set Up Telegram

**Step 12 — Create a Telegram bot**
1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Give it a name (e.g., "My Assistant")
4. Give it a username (e.g., `myname_openclaw_bot`)
5. Copy the bot token BotFather gives you

**Step 13 — Get your Telegram user ID**
Search for **@userinfobot** on Telegram, send it any message, and it will reply with your numeric user ID. Copy this number.

**Step 14 — Enter credentials in wizard**
When the OpenClaw wizard asks:
- Paste your **bot token** from BotFather
- Enter your **user ID** for the `allowFrom` setting (this restricts who can talk to your bot — put your ID so only you can control it)

---

## Part 4: Add Your Anthropic Key

**Step 15 — Get your API key**
Go to [console.anthropic.com](https://console.anthropic.com) and create an API key. It starts with `sk-ant-...`

> **Have Claude Pro/Max?**
> You can use your subscription instead of paying for API credits. Run `claude setup-token` on your local machine (requires Claude Code CLI) and paste the token when prompted.

**Step 16 — Enter in wizard**
When the wizard asks for Anthropic auth, choose **API Key** and paste it.

---

## Part 5: Finish & Test

**Step 17 — Complete the wizard**
Follow the remaining prompts, accepting defaults for most options. The wizard will install a background daemon so OpenClaw stays running 24/7.

**Step 18 — Verify it's running**
```bash
openclaw status
```
Should show the gateway as running.

**Step 19 — Test it!**
Open Telegram, find your bot, and send it a message. You should get a response. 🎉

---

## Essential Commands

**Server management (run on the VPS):**
```bash
openclaw status          # Check if everything is working
openclaw logs --follow   # View live logs
openclaw gateway restart # Restart the bot
openclaw doctor          # Run health checks
```

**Chat commands (send in Telegram):**
```
/new       Start a fresh conversation
/model     Switch AI models
/compact   Compress long conversations (reduces token usage)
stop       Cancel a running task
```

---

## Troubleshooting

**Bot not responding?**
```bash
openclaw status --all
openclaw logs --follow
```

**Need to redo setup?**
```bash
openclaw configure       # Re-run wizard
```

**SSH asking for password?**
Your key isn't being picked up automatically. Use:
```bash
ssh -i ~/.ssh/id_ed25519 root@YOUR_SERVER_IP
```

---

## Part 6: Workspace Setup (Do This Immediately)

Once you're connected and the bot is running, SSH back in and create your workspace files.

**Step 20 — Navigate to workspace**
```bash
cd ~/.openclaw/workspace
```

**Step 21 — Create your SOUL.md**
```bash
nano SOUL.md
```

Paste and customize:
```markdown
# SOUL.md

## Who I Am
You are [Name] — [your description].
[Personality traits. How you communicate.]

## How I Work
- Be resourceful before asking
- Have opinions — I'm allowed to disagree
- Skip corporate filler — just help
- Document what's worth remembering

## My Vibe
[Tone, language, style]

## My Limits
- Private things stay private
- Ask before external actions (emails, posts)
- Never send half-baked replies
```

**Step 22 — Create USER.md**
```bash
nano USER.md
```

```markdown
# USER.md

## About Me
- Name: [Your name]
- What to call me: [Nickname]
- Timezone: [Your timezone, e.g. Europe/Paris]
- Communication style: [Direct/casual/formal]

## Current Focus
[What you're working on right now]
```

**Step 23 — Browse skills at ClawHub**

Skills are instruction sets that teach your agent specialized capabilities. Install the essential ones:

```bash
npm install -g clawhub
clawhub install gog          # Gmail + Google Calendar
clawhub install weather      # Weather lookups
clawhub install humanizer    # Removes AI writing patterns
openclaw gateway restart     # Required after installing skills
```

Browse more at [clawhub.com](https://clawhub.com)

**Step 24 — Join the Discord community**

The OpenClaw Discord is where you get the fastest help, find new skills, and see what operators are building. Search "OpenClaw Discord" or check openclaw.ai for the invite link.

---

## The 5-Minute Daily Habit

Once your agent is running, the maintenance is minimal. But these habits make it dramatically more useful over time:

1. **End each session:** 2 minutes updating `memory/YYYY-MM-DD.md` with decisions and context
2. **Weekly:** Review daily notes, distill key learnings into `MEMORY.md`
3. **Monthly:** Review and prune MEMORY.md — keep it under 500 lines

That's it. The agent does the rest.

---

## What to Build First

You're set up. Now what?

Start with one workflow from Chapter 7 that solves a real problem you have today. Don't try to automate everything at once.

The pattern that works:
1. Pick the task you repeat most often
2. Write it as a clear task description
3. Set it up as a cron job or daily habit
4. Let it run for a week
5. Evaluate, iterate, expand

One good workflow beats ten half-baked ones.
