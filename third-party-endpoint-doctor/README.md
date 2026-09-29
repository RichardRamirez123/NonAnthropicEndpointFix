# third-party-endpoint-doctor

A Claude Code plugin that diagnoses and fixes **tool calls that hang or freeze when
`ANTHROPIC_BASE_URL` points at a non-Anthropic endpoint** — DeepSeek, OpenRouter,
Groq, LiteLLM, a Bedrock/Vertex gateway, or any proxy.

If your Claude Code tool calls stall and you have to press Esc to get unstuck, this
is very likely your problem.

## Symptoms

You are probably in the right place if any of these sound familiar:

- **A tool call never finishes.** The UI shows the agent "doing something", but
  nothing renders on screen. It sits there indefinitely.
- **You press Esc to unstick it.** The call is then recorded in the transcript as
  `The user doesn't want to proceed with this tool use` — so logs look like *you*
  declined a call, when in fact you were escaping a hang.
- **You see a classifier-billing notice:**

  > We're changing auto mode to no longer charge for classifier requests in Claude
  > Code. However, this session isn't eligible because your requests go through
  > `<your host>`, which isn't compatible with this update. Nothing breaks: auto
  > mode keeps working, and its classifier requests are billed as before.

- **`WebSearch` and `WebFetch` hang**, while local tools (`Read`, `Edit`, `Grep`)
  work fine.
- **It started after upgrading past 2.1.277.**

Note that this leaves almost nothing in your logs. A call that never returns never
writes an error, so transcript scanners report "0 malformed calls, 0 errors" while
the problem happens on every single call. If someone has told you it isn't real
because the logs are clean, that reasoning is backwards.

## Root cause

Auto mode gates tool calls behind a **permission classifier**. The changelog shows it
moving server-side:

| Version | Change |
|---|---|
| 2.1.278 | Auto mode defaults to the **server-side** classifier; it "does not charge for classifier overhead" and "warns on billed fallback" |
| 2.1.281 | "where its classifier review runs server-side, read-only and sandboxed shell commands also **wait** for that review" |
| 2.1.282 | Server-side default extended to a direct Anthropic API connection |
| 2.1.283+ | Interactive sessions on third-party providers **start in auto mode** by default |

A tool call **waits** on that review. On an endpoint that cannot serve it, the review
never returns — so the call waits forever. That is the hang.

The billing notice is the **same feature** surfaced as a pricing change: you are not
eligible for the free server-side classifier, so you keep the billed local one. It
reads like a billing problem, which is why it sends people down the wrong path.

**2.1.277 predates all of this**, which is why downgrading appears to fix it. The
downgrade isn't repairing a regression — it's removing the server-side default. That
is also why the fix below works without downgrading.

## The fix

Add one line to the `env` block of `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_AUTO_MODE_SERVER": "0"
  }
}
```

This forces the **local** classifier — exactly what 2.1.277 was effectively using.
Restart Claude Code afterwards.

Classifier requests then count toward usage, which the notice already told you would
be the case.

**Alternative:** set `permissions.defaultMode` (e.g. `"acceptEdits"`) so sessions
never enter auto mode at all.

**If `WebSearch` also hangs:** that tool is Anthropic-hosted and cannot be served by a
third-party endpoint either. Prefer `WebFetch` against a specific URL, or supply an
MCP search server.

## Install

```
/plugin marketplace add <this-repo>
/plugin install third-party-endpoint-doctor
```

Or, without a marketplace, copy this directory into `~/.claude/skills/` sibling
locations as your setup requires, or point at it directly.

## Use

```
/endpoint-doctor
```

It checks your endpoint, whether the classifier is pinned, whether sessions start in
auto mode, **which build is actually running** (a version pin can silently fail to
reach the active binary), and whether transcripts corroborate a stall — then offers
the fix and applies it only with your confirmation.

The bundled `third-party-endpoint` skill also triggers automatically when you
describe the symptom, so you can just say "my tool calls keep freezing".

## Confidence — read this

The **fix is well-supported**: it is a documented configuration flag, and it is what
resolves the symptom in practice.

The **mechanism is inferred**, from changelog entries plus correlation, and has not
been reproduced under controlled conditions. In particular, no transcript shows a
call *waiting* on a classifier review — a hang cannot leave that trace, which is
precisely why the problem is so hard to confirm from logs.

The decisive test: remove `CLAUDE_CODE_AUTO_MODE_SERVER` and confirm the stall
returns. Until that is run and recorded, treat the causal chain as strongly
suggested rather than proven.

## Scope

Written for Claude Code on a non-Anthropic endpoint. If you are on `api.anthropic.com`
directly, this plugin does not apply to you.

## License

MIT
