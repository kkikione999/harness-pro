# Step 2 — Restate the Requirement and Wait for Approval

Goal: prove to the user that you understood the request, surface any ambiguity, and get explicit go-ahead before any planning happens.

## What to write in the restatement

Keep it short. The user already knows what they asked for; they're checking whether you got it right. Aim for **3 short sections**:

1. **Goal** — one sentence in the user's vocabulary, not yours. If they said "make the dashboard load faster", don't translate to "optimize render-path latency."
2. **In scope / Out of scope** — two short bullet lists. The "out of scope" list is where misunderstandings die. Be explicit about what you are NOT going to touch.
3. **Done when** — 1–3 verifiable conditions. "Tests pass and the dashboard renders in under 500ms on the staging dataset", not "it feels faster."

If the request has unresolved ambiguity, ask in this same turn — don't ask later. Phrasing template:

> "Before I plan, I want to confirm: [the part I'm unsure about]. Is that right, or did you mean [alternative]?"

## The gate

After you post the restatement, **stop and wait**. Do not call `plan-agent`, do not start reading more files, do not begin implementation, do not call any other tool that materially changes anything.

Wait for one of:
- An explicit affirmative — "yes", "go", "approved", "looks good", "ship it", "do it", or any clear equivalent
- A correction — apply the correction, then restate again and wait again
- A question — answer it, then restate and wait again

If the user replies with something ambiguous like "ok" or "👍", treat it as approval. If they reply with something that could be either ("sure, but also…"), apply the additional constraint and restate once more before proceeding.

## Why the gate is non-negotiable

The cost of one extra approval round-trip is ~30 seconds of user time. The cost of building the wrong thing for an hour is much higher, and worse, the user has to read the wrong work to discover the misunderstanding. Every long-task post-mortem starts with "we should have caught this in the restatement."

## Skip rules

There are none. Even if you are 99% sure you understood, the 1% case is what this gate exists for. If the user has explicitly told you in CLAUDE.md or in this session that they don't want approval gates, then and only then can you skip — but mention it in your restatement so they can correct you.
