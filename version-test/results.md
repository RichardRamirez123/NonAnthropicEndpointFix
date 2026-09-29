# Tool-surface exercise results

One block per Claude Code version. Run `version-test/EXERCISE.md` in a fresh session
under each version, append the block, then compare.

Reference points:

- **2.1.277** — suspected-good build, current frozen version
- **2.1.284** — newest build (npm `latest`, released 2026-09-28); what `stable` becomes
  in roughly a week

---

<!-- Append new result blocks below this line. -->

## 2.1.277 — 2026-09-28 13:20 (smoke test; round 1 only, run in-session)

Round 1: 1=OK 2=OK 3=OK 4=OK 5=OK 6=OK 7=OK 8=OK

Retries observed: 0
Failures observed: 0
Notes: Run to validate the exercise itself, not as a complete measurement — only
one round, so it cannot speak to intermittency. All eight probes passed on the
first attempt. Probe 7 returned 15 and probe 8 returned 1337 as expected.

### transcript scan

The first version of check-transcript.ps1 reported 5 malformed signatures in this
session. Those were FALSE POSITIVES: the changelog page fetched during this session
quotes all five error strings verbatim as documentation text, and the scan matched
fetched content. Fixed by gating on `is_error` as well as `tool_result` scope.
Lesson worth keeping: any text-based scan of transcripts will match documentation
that quotes error strings, so scope the scan to error blocks only.

Wider scan across 6 recent transcripts found **zero malformed tool calls**. The 16
tool errors present were: 14 permission denials ("The user doesn't want to proceed
with this tool use") and 2 "File does not exist" (reads from an empty working
directory). The exercise's original framing targeted the wrong failure mode.

---

## Finding: the failure was an auto-mode hang, not a broken tool

**Reported symptom (user, verbatim):** "the prompts weren't going through it would
get stuck completely and never finish the prompt."

**Mechanism.** Three changelog entries combine:

- **2.1.278** (Sep 19) — "Changed auto mode for Claude API and Enterprise users, and
  on Bedrock, Vertex, Foundry and gateways, to default to the **server-side**
  classifier … (`CLAUDE_CODE_AUTO_MODE_SERVER=0` opts out …)"
- **2.1.283** (Sep 25) — "Changed interactive sessions on **third-party providers** or
  with telemetry off to start in **auto mode** when no permission mode is configured;
  `permissions.defaultMode` still overrides it"
- **2.1.284** (Sep 28) — same auto-mode default, extended to "every plan and provider"

So on 2.1.283+, sessions on this machine (`ANTHROPIC_BASE_URL=api.deepseek.com/anthropic`)
start in auto mode, whose classifier review defaults to Anthropic's servers. That
review cannot be served by a third-party endpoint, and 2.1.281 confirms tool calls
**wait** on that review: "where its classifier review runs server-side, read-only and
sandboxed shell commands also wait for that review." A review that never returns
means the call waits forever — a hang, matching the reported symptom.

The 14 "user doesn't want to proceed" denials are then a *symptom*, not the cause:
the natural response to a prompt that hangs forever is to reject it and try again.

**Version boundary confirms it:** 2.1.277 is the last build before 2.1.283, so the
downgrade stepped back across the auto-mode default. Not a tool regression.

**Fix applied** (`~/.claude/settings.json`) — prefer the local classifier so no
review round-trips to a server this endpoint cannot reach:

```json
"env": { "CLAUDE_CODE_AUTO_MODE_SERVER": "0" }
```

**Confound ruled out:** malformed tool calls were zero across six transcripts, so the
third-party model's function-calling was never the problem here. The scanner now
counts denials separately from malformed calls for exactly this reason.

**Still unverified:** whether option A alone clears the hang on 2.1.284. That needs a
real run under that build — see the test steps below.

---

## 2.1.284 — 2026-09-28 13:16

Round 1: 1=OK 2=OK 3=OK 4=OK 5=OK 6=OK 7=OK 8=OK
Round 2: 1=OK 2=OK 3=OK 4=OK 5=OK 6=OK 7=OK 8=OK
Round 3: 1=OK 2=OK 3=OK 4=OK 5=OK 6=OK 7=OK 8=OK

Retries observed: 0
Failures observed: 0

Notes: 24/24 probes succeeded on the first attempt. All eight expected values
matched exactly (`PROBE-ALPHA-7391`, `PROBE-BETA-7391`, 1 Grep match, `probe.txt`,
sum `15`, product `1337`). No error text at all this run, so nothing to quote. No
unusual latency. Three things worth recording beyond the score:

**1. Attribution is solid — this really is 2.1.284.** Step 0 output verbatim:
`2.1.284 (Claude Code)`. Verified against the running process rather than trusting
the CLI alone: `Get-CimInstance Win32_Process` shows the live process is
`C:\Users\richi\.local\bin\claude.exe`, whose `VersionInfo.FileVersion` is
`2.1.284.0` (246480032 bytes). `where.exe claude` resolves to that same path, so no
second install is shadowing it. The result block is correctly attributed.

**2. The freeze to 2.1.277 is not in effect, despite the settings still saying so.**
`settings.json` still carries `DISABLE_AUTOUPDATER: "1"` and
`.last-update-result.json` still records `"version_from":"2.1.284","version_to":"2.1.277",
"outcome":"success"` (2026-09-28T19:47:33Z). But `~/.local/share/claude/versions`
holds `2.1.277` (12:47:30), `2.1.282`, and `2.1.284` (12:07:44), and the *active*
binary is 2.1.284 — with a LastWriteTime (12:07:44) that predates the 12:47 downgrade
that was supposed to replace it. So the downgrade landed in the versions directory
without reaching `bin\claude.exe`. The pin is not holding on this machine.
Two consequences: (a) the previous block's attribution needs re-checking — it is
headed `2.1.277`, and its own header time is independently suspect, since results.md's
LastWriteTime is `13:09:05` while that block claims `13:20`, which is impossible;
(b) any future run must re-verify the version the same way rather than assuming the
freeze held.

**3. This is the 2.1.284 run that was listed as still unverified.** The section above
wanted a real run under 2.1.284 to test whether `CLAUDE_CODE_AUTO_MODE_SERVER=0`
alone clears the hang. This was one: three full rounds, 24 tool calls, running under
2.1.284 with that env var set. Nothing hung, stalled, or needed a retry. That is
genuine positive evidence, but it is weak on its own — every probe is a fast local
file operation that would not obviously route through the server-side classifier
review that caused the hang, so this run may simply never have exercised the failing
path. Treat it as "no reproduction", not as "fix confirmed".

### transcript scan

```
$ powershell -File version-test\check-transcript.ps1
Scanning 7 transcript(s) modified in the last 60 minute(s).

  0c9b0776  denials=0  malformed=0  other=0
  6563e4ea  denials=0  malformed=0  other=0
  77d65f6c  denials=0  malformed=0  other=0
  7e7dc791  denials=1  malformed=0  other=1
  bfe22cc8  denials=1  malformed=0  other=0
  e85f1de2  denials=9  malformed=0  other=0
  fb4d2cf3  denials=3  malformed=0  other=1

TOTALS across 7 transcript(s):
  permission denials : 14
  malformed calls    : 0
  other tool errors  : 2

Reading:
  - No malformed calls, but 14 denial(s): the tools are fine and the
    CALLS were refused. Look at permission mode / the auto-mode classifier,
    not at the build.
```

Scan clean, rounds all OK → per the exercise's own rubric, 2.1.284's tool layer is
healthy. The 14 denials are the historical ones already analysed above (same count
and same distribution as the previous scan, so this run added none), not new
failures. Cross-check agrees with the self-report for once: 24 first-attempt
successes, 0 malformed signatures, 0 denials originating in this session.

