---
name: third-party-endpoint
description: Use when tool calls on Claude Code stall, hang, freeze, or appear to do nothing while the UI shows the agent working, especially when ANTHROPIC_BASE_URL points at a non-Anthropic endpoint such as DeepSeek, OpenRouter, Groq, a proxy, or a self-hosted gateway. Also use when the user sees the "isn't eligible because your requests go through <host>, which isn't compatible with this update" classifier-billing notice, or has to press Esc to unstick every call. Diagnoses the auto-mode classifier mismatch and applies the fix.
version: 0.1.0
license: MIT
---

# Stalled tool calls on a third-party endpoint

## What the user reports

The symptom cluster is distinctive. Look for two or more of:

- A tool call never completes. The UI shows the agent "doing something", but
  nothing renders on screen.
- The user **presses Esc to get unstuck**, and the call is then recorded as
  `The user doesn't want to proceed with this tool use` — so transcripts look
  like the *user* refused a call when in fact they were escaping a hang.
- A notice appears: *"We're changing auto mode to no longer charge for classifier
  requests… this session isn't eligible because your requests go through
  `<host>`, which isn't compatible with this update. Nothing breaks: auto mode
  keeps working, and its classifier requests are billed as before."*
- `WebSearch` / `WebFetch` hang while local file tools (`Read`, `Edit`) work.
- Trouble starts after upgrading past **2.1.277**.

Critically: **a hang leaves no error record.** `check-transcript`-style scans show
zero malformed calls and near-zero errors, because a call that never returns never
writes an error. Absence of errors in a transcript is NOT evidence the problem
isn't real. Weight the user's first-hand account over the log.

## Diagnosis

Establish these five facts before proposing anything.

1. **Is the endpoint non-Anthropic?** Read `ANTHROPIC_BASE_URL` from the
   environment and from the `env` block of `~/.claude/settings.json`. Anything
   whose host is not `api.anthropic.com` (DeepSeek, OpenRouter, a LiteLLM or
   Bedrock gateway) qualifies.

2. **Is the classifier pinned?** Check `env.CLAUDE_CODE_AUTO_MODE_SERVER` in
   `~/.claude/settings.json`. `"0"` forces the local classifier. Absent or `"1"`
   means the server-side classifier may be in use.

3. **Will sessions start in auto mode?** Check `permissions.defaultMode`. If it is
   unset, builds 2.1.283+ start interactive sessions in auto mode by default.

4. **Which build is actually running?** Do not trust `settings.json`,
   `autoUpdatesChannel`, or a recorded-successful downgrade. Confirm directly:
   `Get-CimInstance Win32_Process -Filter "name like '%claude%'"` for the live
   executable, then read that file's `VersionInfo.FileVersion`. A version pin that
   "succeeded" can still fail to reach the active binary.

5. **Does the transcript corroborate?** Scan for denials (`doesn't want to
   proceed`, `denied by the Claude Code auto mode classifier`). Note that the
   denials are the *symptom* of Esc-to-unstick, not the cause.

## The mechanism

From **2.1.278**, auto mode defaults its permission classifier to Anthropic's
servers — "does not charge for classifier overhead", and it "warns on billed
fallback". **2.1.282** extended that default. **2.1.281** made it worse: "where its
classifier review runs server-side, read-only and sandboxed shell commands also
wait for that review". Tool calls *wait* on that review.

On an endpoint that cannot serve it, the review never returns, so the call waits
forever. **2.1.277 predates all of this**, which is why downgrading appeared to fix
it — the downgrade did not repair a regression, it removed the server-side default.

The billing notice is the *same feature*, surfaced as a pricing change. It is not a
separate problem, and it is not itself the cause — but its arrival dates the
classifier change, so it is useful corroboration.

## The fix

Prefer the configuration change over a version rollback — it is available on the
newest build, and rollbacks fight the updater.

**Primary:** add to the `env` block of `~/.claude/settings.json`:

```json
"CLAUDE_CODE_AUTO_MODE_SERVER": "0"
```

This forces the local classifier, which is what 2.1.277 was effectively using.
Classifier requests are then billed as before, which the notice already told the
user.

**Alternative:** set `permissions.defaultMode` (e.g. `"acceptEdits"` or `"default"`)
so sessions never enter auto mode.

**Also worth flagging:** `WebSearch` and other Anthropic-hosted server-side tools
cannot be served by a third-party endpoint either, and hang the same way. On such a
setup, prefer `WebFetch` against a specific URL over `WebSearch`, or use an MCP
search server the user supplies.

A restart is required after editing settings.

## Honesty requirements

State the confidence level plainly. The mechanism is **inferred** from changelog
entries plus correlation, and has not been reproduced under controlled conditions.
The decisive test is unsetting `CLAUDE_CODE_AUTO_MODE_SERVER` and confirming the
stall returns. If you have not run that test, say so — do not present the mechanism
as established fact. Do not tell the user their hang isn't real because it left no
trace in the logs.
