# Chapter 5 (REVISED): Multi-Agent Systems, Sub-Agents & Agent Teams

## The Three Levels of AI Collaboration

Most people think about AI as one model, one conversation. That's Stage 1 thinking.

The real power is in orchestration — multiple AI instances working together, in parallel, with different roles and specializations. OpenClaw supports three distinct patterns, each more powerful than the last.

---

## Level 1: Sub-Agents (Available Now)

Sub-agents are the entry point. They're background agent runs spawned from your main session — isolated, parallel, and reporting back when done.

**How it works:**

```
Main Agent (you talk to this)
├── Sub-agent 1: Research task → runs in background
├── Sub-agent 2: Writing task → runs in background  
└── Sub-agent 3: Code review → runs in background
           ↓
All three complete and announce results back
```

**Spawning a sub-agent via tool:**

```javascript
sessions_spawn({
  task: "Research the top 10 AI workflow tools in 2026. 
        Focus on pricing, unique features, and target audience.
        Return a structured report with a comparison table.",
  label: "market-research",
  model: "anthropic/haiku",  // cheaper model for sub-tasks
  runTimeoutSeconds: 300
})
```

**Spawning via slash command:**

```
/subagents spawn main "Research competitors for X product"
/subagents list                    # see running sub-agents
/subagents log 1 50                # see last 50 lines of output
/subagents steer 1 "Focus on EU market only"  # redirect mid-run
/subagents kill all                # kill all running sub-agents
```

**Key behaviors:**
- Each sub-agent has its own context window — it doesn't see your main conversation
- Sub-agents can't message each other directly (only report back to main)
- Use cheaper models for sub-tasks, keep main agent on quality model
- Non-blocking: your main session continues while sub-agents work

**Cost optimization pattern:**

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "model": "anthropic/haiku",
        "thinking": "off"
      }
    }
  }
}
```

Run routine sub-tasks on Haiku. Reserve Sonnet for your main orchestrator. This cuts multi-agent costs by 60-80%.

---

## Level 2: Agent Teams (Experimental — Feb 2026)

On February 5, 2026, Anthropic shipped Agent Teams — a fundamentally different architecture. Unlike sub-agents (which only talk to the main agent), Agent Teams are fully independent Claude instances that communicate *directly with each other*.

**Sub-agents vs. Agent Teams:**

| Aspect | Sub-agents | Agent Teams |
|--------|-----------|-------------|
| Context | Inside main session | Each has own context |
| Communication | Results return to main only | Teammates message each other |
| Coordination | Main agent handles everything | Self-coordination via shared task list |
| Token cost | Lower | Scales with team size |
| Use case | Parallel tasks | Complex projects requiring collaboration |

**Enabling Agent Teams:**

```bash
# Option 1: Environment variable (session only)
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Option 2: Persistent (recommended)
# Add to ~/.claude/settings.json:
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Requires OpenClaw dev channel:
```bash
openclaw update --channel dev
openclaw gateway restart
```

**Configuring team display mode:**

```json
{
  "teammateMode": "tmux"  // each teammate gets its own pane
}
```

Options: `in-process` (default terminal), `tmux` (split panes), `iTerm2` (auto-split). For production monitoring, `tmux` is the best — you see all teammates at once.

**Designing your teams — real example (5 specialized teams):**

```
Create 5 agent teams:
- ops: Infrastructure operations, gateway health, cron monitoring
- research: Market analysis, competitor tracking, data gathering
- content: Writing, repurposing, multilingual management
- dev: Code review, refactoring, feature implementation
- distribution: Social media, community monitoring, outreach
Assign 2 teammates to each team using the Sonnet model.
```

**The shared task list — the core coordination mechanism:**

Teams work through a shared task list. The team lead creates tasks; teammates autonomously claim and execute them.

Task states: `pending` → `in_progress` → `completed`

Dependencies prevent downstream tasks from starting until prerequisites are done:

```
Task list:
1. [research] Competitor pricing analysis
2. [research] Reddit sentiment scan (→ depends on #1)
3. [content] Draft landing page copy (→ depends on #1)
4. [content] Write email sequence (→ depends on #3)
5. [dev] Build checkout integration
6. [ops] Deploy to Vercel (→ depends on #5)
```

Task claiming uses file locking to prevent race conditions.

**Delegate mode:**

By default, the team lead can do work directly. In delegate mode (Shift+Tab), the lead only:
- Spawns and shuts down teammates
- Relays messages between teams
- Manages the task list

Pure coordination — no direct execution. This is the right mode once your teams are calibrated.

---

## Level 3: The CLAUDE.md Pattern (Persistent Agent Design)

When you run Agent Teams or sub-agents at scale, the CLAUDE.md file becomes critical. It's not just a persona document — it's the operating manual for each specialized agent.

**Structure for specialized agents:**

```markdown
# CLAUDE.md — Research Agent

## Identity
You are a research specialist. Your job is to gather,
synthesize, and structure information. You do not write
prose, you do not make strategic decisions. You research
and report.

## Your workflow
1. Always start by clarifying what "done" looks like
2. Use web_search for breadth, web_fetch for depth
3. Cite every claim with a source URL
4. Structure output as: Summary → Key Findings → Data → Sources

## What you don't do
- Don't make recommendations (that's the strategist's job)
- Don't write marketing copy
- Don't touch code

## Quality bar
Your output is only ready when:
- Every major claim is sourced
- The summary is under 200 words
- A non-expert could understand it
```

Each agent in a team should have its own CLAUDE.md with clear role, workflow, quality bar, and explicit boundaries.

---

## The Planning Step — Why Most Multi-Agent Setups Fail

This is the chapter that separates good agent systems from bad ones.

Most people run agents like this:
```
Human → "Do X" → Agent starts doing X immediately
```

This fails at scale. The agent makes assumptions, goes in the wrong direction, does work that needs to be redone.

**The right pattern:**

```
Human → "Plan X, don't execute" → Agent creates plan
Human → reviews plan, approves/adjusts
Human → "Execute the plan" → Agent executes with clarity
```

This seems slower. It's actually 3x faster because you eliminate rework.

**How to force the planning step:**

Add this to your main agent's AGENTS.md:

```markdown
## Planning Protocol

For any task that will take more than 10 minutes or
involves multiple steps:

1. FIRST, write a plan:
   - Break the task into concrete steps
   - Identify dependencies between steps
   - Flag any assumptions or questions
   - Estimate which steps can be parallelized
   
2. PRESENT the plan before doing anything
3. WAIT for approval before executing
4. On approval, execute step by step

Do not start execution until the plan is approved.
"Seems clear" is not an approval — wait for explicit "go".
```

**The planning template:**

When your agent presents a plan, it should look like this:

```
## Plan: [Task Name]

**Goal:** [One sentence — what done looks like]

**Steps:**
1. [Step] → [Who does it] → [Output]
2. [Step] → [Depends on: 1] → [Output]
3. [Step] → [Can run parallel with: 2] → [Output]

**Assumptions:**
- [Assumption 1 — flag if wrong]
- [Assumption 2]

**Risks:**
- [Risk] → [Mitigation]

**Estimated time:** X minutes

Ready to proceed? (yes / adjust: [feedback])
```

This format forces clarity before action. The 30 seconds it takes to review a plan saves you from 30 minutes of "wait, not like that."

**For Agent Teams specifically:**

The team lead should always run a planning phase before creating the task list. Tasks created without a plan are just chaos with structure.

```
To team lead:
Before assigning tasks, create a project plan:
1. What is the final deliverable?
2. What are the dependencies?
3. Which tasks can run in parallel?
4. What are the handoff points between teams?

Only create the task list after this plan is reviewed.
```

---

## Practical Multi-Agent Patterns

### Pattern 1: The Research Swarm

Best for: gathering information on a topic from multiple angles simultaneously.

```
Main agent orchestrates:
├── Sub-agent A: "Search Reddit for [topic] sentiment"
├── Sub-agent B: "Analyze top 5 competitor websites"
└── Sub-agent C: "Find 10 recent articles on [topic]"

Main agent: collects all three outputs, synthesizes
```

Time to complete: 3-4 minutes vs 45+ minutes sequential.

### Pattern 2: The Review Pipeline

Best for: quality assurance, catching errors the primary agent missed.

```
Agent 1 (Writer): Produces draft
      ↓
Agent 2 (Editor): Reviews for clarity, logic, accuracy
      ↓
Agent 3 (Critic): Challenges assumptions, finds gaps
      ↓
Main agent: Makes final judgment call
```

### Pattern 3: The Autonomous Business Operator

The full Agent Teams pattern for running a business unit:

```
ops team: monitors infrastructure, handles incidents
content team: produces weekly content calendar
research team: weekly market intelligence reports
dev team: handles code review and small features
distribution team: posts, monitors, responds
```

Main agent sits above all teams, handles strategy and escalations. The teams handle execution.

This is not a demo. I run a version of this daily.

---

## The Honest Limitation

Multi-agent systems are powerful. They're also expensive and complex.

Before you build a 5-team Agent Teams setup, ask:
- Have I fully explored what a single well-configured agent can do?
- Is this complexity justified by the output?
- Do I have the context management (CLAUDE.md per agent) to make it reliable?

The answer is often: start with sub-agents, graduate to teams when you've hit the ceiling.

The single-agent ceiling is higher than most people think.
