# Claude Code tool-surface exercise

Purpose: detect **intermittent malformed tool calls** — the suspected failure mode on
this machine, where models route to `api.deepseek.com` via `ANTHROPIC_BASE_URL`.

Run this once per Claude Code version, then compare the two result blocks in
`results.md`.

**Rules that make the result meaningful:**

- Each probe is **exactly one tool call**. Do not batch several probes into one call.
- Do not pre-create files or "help" a failed probe by hand. Report failure as failure.
- If a tool call returns an error, **note it, then re-issue it** — a retry is itself
  the signal we're hunting. Retries are evidence, not noise to be hidden.
- Run all 3 rounds. Intermittent failures hide in single runs.

## Invocation

From a fresh session whose working directory is `C:\Users\richi\Desktop\Notes`:

> Run the exercise in version-test/EXERCISE.md

## Step 0 — record the version

Run `claude --version` and record the exact output verbatim. This attributes the
result block to a build.

## Step 1 — run 3 rounds

Each round: delete `version-test/sandbox/`, recreate it, then run probes 1–8 in order.

| # | Tool | Call | Expected result |
|---|---|---|---|
| 1 | Write | create `version-test/sandbox/probe.txt` with exactly `PROBE-ALPHA-7391` | file written |
| 2 | Read | read `version-test/sandbox/probe.txt` | `PROBE-ALPHA-7391` |
| 3 | Edit | in that file, replace `ALPHA` → `BETA` | 1 replacement |
| 4 | Grep | search `version-test/sandbox` for `BETA`, `output_mode: "content"` | 1 match |
| 5 | Glob | pattern `version-test/sandbox/*.txt` | finds `probe.txt` |
| 6 | Write | create `version-test/sandbox/numbers.txt` with lines `1` `2` `3` `4` `5` | file written |
| 7 | PowerShell | `(Get-Content version-test\sandbox\numbers.txt \| Measure-Object -Sum).Sum` | `15` |
| 8 | PowerShell | compute `7 * 191` | `1337` |

## Step 2 — score each probe

For every probe, record one of:

- **OK** — succeeded on the first attempt
- **RETRY** — a tool call returned an error, then a re-issued call succeeded
- **FAIL** — could not be completed

A **RETRY** is the interesting outcome. It means the model emitted a malformed or
mistyped call and recovered — the failure is real even though the end state looks clean.

## Step 3 — append the result block

Append to `version-test/results.md` (create it if missing):

```
## <version> — <YYYY-MM-DD HH:MM>

Round 1: 1=OK 2=OK 3=OK 4=OK 5=OK 6=OK 7=OK 8=OK
Round 2: ...
Round 3: ...

Retries observed: <n>
Failures observed: <n>
Notes: <anything anomalous: wrong parameter names seen, tools that vanished,
        error text quoted verbatim, unusual latency>
```

Keep the notes concrete. Quote error text exactly — "the Write tool failed" is not
usable evidence; `Write: Missing required parameter "content"` is.

## Step 4 — objective check

Model self-report is not proof. Run the independent scan, which counts malformed-tool
signatures straight out of the session transcripts:

```powershell
powershell -File version-test\check-transcript.ps1
```

Append its output to `results.md` under a `### transcript scan` heading.

**How to read the two against each other:**

- Scan clean + all rounds OK → that version's tool layer is healthy.
- Scan finds signatures while rounds show all OK → the model is retrying silently.
  This is the case a self-report would have missed, and it counts as a **failure of
  the exercise's version**.
- Everything fails → reproduce the original breakage; roll back with
  `claude install 2.1.277`.
