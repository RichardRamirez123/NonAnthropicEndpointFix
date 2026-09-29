# Claude Code tool calls hang on a non-Anthropic endpoint

**Fix, plugin and write-up for Claude Code tool calls that freeze when
`ANTHROPIC_BASE_URL` points somewhere other than `api.anthropic.com`** —
DeepSeek, OpenRouter, Groq, LiteLLM, a Bedrock/Vertex gateway, or any proxy.

If your tool calls stall, the agent says it's working, nothing appears on screen,
and you end up pressing Esc to get unstuck — this is for you.

---

## The fix

Open `~/.claude/settings.json` (`%USERPROFILE%\.claude\settings.json` on Windows)
and add:

```json
"env": {
  "CLAUDE_CODE_AUTO_MODE_SERVER": "0"
}
```

If an `env` block already exists, add just that one line inside it. **Restart
Claude Code** — the setting is read at startup.

Classifier requests then bill as before, which a notice you may have seen already
told you.

### Or have Claude Code do it

Paste this into Claude Code:

```text
Diagnose and fix the third-party-endpoint tool-call hang on this machine.

1. Read ~/.claude/settings.json. Report the ANTHROPIC_BASE_URL and the env block.
2. If ANTHROPIC_BASE_URL's host is not api.anthropic.com, and
   env.CLAUDE_CODE_AUTO_MODE_SERVER is missing or not "0":
     - back up settings.json first
     - add "CLAUDE_CODE_AUTO_MODE_SERVER": "0" to the env block
     - preserve every other setting exactly as it was
3. Confirm the change by re-reading the file, then tell me to restart Claude Code.
```

### Or run the script

[`fix-endpoint-hang.ps1`](fix-endpoint-hang.ps1) does the same thing on Windows,
with a backup and a dry run:

```powershell
powershell -File fix-endpoint-hang.ps1          # dry run, changes nothing
powershell -File fix-endpoint-hang.ps1 -Apply   # writes it
```

It checks your endpoint first and stays out of the way if the fix doesn't apply.
If `settings.json` is malformed it refuses to touch it rather than risk your
config.

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
server-side default. `CLAUDE_CODE_AUTO_MODE_SERVER=0` gets the same local
classifier without downgrading.

### The notice you may have seen

> We're changing auto mode to no longer charge for classifier requests in Claude
> Code. However, this session isn't eligible because your requests go through
> `<your host>`, which isn't compatible with this update. Nothing breaks: auto
> mode keeps working, and its classifier requests are billed as before.

Same feature, seen from the billing side. It reads like a billing problem and says
"nothing breaks", which is why it sends people down the wrong path.

### Why your logs look clean

A call that never returns never writes an error. Transcript scanners report
"0 malformed calls, 0 errors" while the freeze happens on every call. **A clean log
is not evidence the problem isn't real** — if something tells you it's fine because
nothing shows up, that reasoning is backwards.

### Also worth knowing

- **`WebSearch` may hang too** — it's Anthropic-hosted, so a third-party endpoint
  can't serve it either. Prefer `WebFetch` on a specific URL, or an MCP search
  server.
- **A version pin can silently fail.** One machine here had a recorded-successful
  downgrade to 2.1.277 while the running binary was still 2.1.284. Verify via the
  live process path and its file version, not via the config.
- **`permissions.defaultMode`** is the alternative escape — set it and sessions
  never enter auto mode at all.

---

## Install as a plugin

```
/plugin marketplace add RichardRamirez123/NonAnthropicEndpointFix
/plugin install third-party-endpoint-doctor@non-anthropic-endpoint-fix
```

Then run `/endpoint-doctor`. It checks your endpoint, whether the classifier is
pinned, whether sessions start in auto mode, **which build is actually running**,
and whether transcripts corroborate a stall — then offers the fix and applies it
only with your confirmation.

The bundled skill also triggers on its own, so you can just say *"my tool calls
keep freezing"*.

See [`third-party-endpoint-doctor/`](third-party-endpoint-doctor/) for the plugin
source.

---

## Confidence — read this

**The fix is well-supported** — it's a documented configuration flag and it
resolves the symptom in practice.

**The mechanism is inferred**, from changelog entries plus correlation, and has
not been reproduced under controlled conditions. No transcript shows a call
*waiting* on a classifier review, because a hang can't leave that trace — which is
exactly why this problem is so hard to confirm from logs.

The decisive test is to remove the setting and confirm the freeze returns. Until
that's recorded, treat the causal chain as strongly suggested rather than proven.

The longer write-up lives in
[`deepseek-claude-code-fix.md`](deepseek-claude-code-fix.md). The raw
investigation notes — and the transcript-scanning script used to test the claims
above — are in [`version-test/`](version-test/).

---

## License

MIT — see [LICENSE](LICENSE).
