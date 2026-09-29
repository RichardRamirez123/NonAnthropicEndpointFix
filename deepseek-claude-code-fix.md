# Claude Code + DeepSeek: fix tool calls that hang

**If your Claude Code tool calls freeze — the agent says it's working, nothing
appears on screen, and you have to press Esc to get unstuck — this is the fix.**

Applies when `ANTHROPIC_BASE_URL` points at a non-Anthropic endpoint: DeepSeek,
OpenRouter, Groq, LiteLLM, a gateway or proxy.

---

## The prompt

Copy everything inside the box and paste it into Claude Code:

```text
Diagnose and fix the third-party-endpoint tool-call hang on this machine.

1. Read ~/.claude/settings.json. Report the ANTHROPIC_BASE_URL and the env block.
2. If ANTHROPIC_BASE_URL's host is not api.anthropic.com, and
   env.CLAUDE_CODE_AUTO_MODE_SERVER is missing or not "0":
     - back up settings.json first
     - add "CLAUDE_CODE_AUTO_MODE_SERVER": "0" to the env block
     - preserve every other setting exactly as it was
3. Confirm the change by re-reading the file, then tell me to restart Claude Code.

Then explain in two sentences why this works: from Claude Code 2.1.278, auto mode
defaults its permission classifier to Anthropic's servers; a third-party endpoint
cannot serve that review, and tool calls wait on it, so the call never returns.
```

That's it. Restart Claude Code afterwards — the setting is only read at startup.

---

## The one-line version

If you'd rather edit it yourself, open `%USERPROFILE%\.claude\settings.json`
(Windows) or `~/.claude/settings.json` (macOS/Linux) and make sure it contains:

```json
"env": {
  "CLAUDE_CODE_AUTO_MODE_SERVER": "0"
}
```

If an `env` block already exists, just add that one line inside it.

---

## Why this happens

Claude Code's **auto mode** puts a permission classifier in front of tool calls.
The changelog shows that classifier moving to Anthropic's servers:

| Version | Change |
|---|---|
| 2.1.278 | Auto mode defaults to the **server-side** classifier — "does not charge for classifier overhead", and it "warns on billed fallback" |
| 2.1.281 | "where its classifier review runs server-side, read-only and sandboxed shell commands also **wait** for that review" |
| 2.1.282 | Server-side default extended to a direct Anthropic API connection |
| 2.1.283+ | Interactive sessions on third-party providers **start in auto mode** by default |

Tool calls **wait** on that review. A third-party endpoint can't serve it, so the
review never returns — the call waits forever. That is the freeze.

**2.1.277 predates all of it**, which is why downgrading appears to fix the
problem. The downgrade isn't repairing a regression, it's removing the
server-side default. `CLAUDE_CODE_AUTO_MODE_SERVER=0` gets you the same local
classifier without downgrading.

### The notice you may have seen

> We're changing auto mode to no longer charge for classifier requests in Claude
> Code. However, this session isn't eligible because your requests go through
> `<your host>`, which isn't compatible with this update. Nothing breaks: auto
> mode keeps working, and its classifier requests are billed as before.

This is the **same feature** seen from the billing side. It reads like a billing
problem and says "nothing breaks", which is why it sends people down the wrong
path. It is not itself the cause — but its arrival dates the change.

### Why the logs look clean

A call that never returns never writes an error. So transcript scanners report
"0 malformed calls, 0 errors" while the freeze happens on every call. **A clean
log is not evidence the problem isn't real** — if someone tells you it's fine
because nothing shows up, that reasoning is backwards.

---

## Confidence

**The fix is well-supported** — it's a documented configuration flag and it
resolves the symptom in practice.

**The mechanism is inferred**, from changelog entries plus correlation. It has
not been reproduced under controlled conditions: no transcript shows a call
*waiting* on a classifier review, because a hang can't leave that trace.

The decisive test is to remove the setting and confirm the freeze returns. Until
that's recorded, treat the causal chain as strongly suggested rather than proven.

---

## Also worth knowing

- **`WebSearch` may hang too.** It's an Anthropic-hosted server-side tool, so a
  third-party endpoint can't serve it either. Prefer `WebFetch` on a specific
  URL, or an MCP search server.
- **A version pin can silently fail.** One machine here had a recorded-successful
  downgrade to 2.1.277 while the running binary was still 2.1.284. Verify with
  the live process path and its file version, not with the config.
- **`permissions.defaultMode`** is the alternative escape — set it and sessions
  never enter auto mode at all.
