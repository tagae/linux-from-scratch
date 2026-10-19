# Brief for every agent working on <JOB>

<!-- Copy to the scratchpad, fill the <...>, delete what does not apply; each agent's prompt points here.
     Agents append to the last section. -->

Repo: <path> (<host>, <how builds run>, target <platform>). Plan with pins: <research plan path>.
Scratchpad: <path>

## Goal
<What the user wants, in their words; who uses the result and when; the target artifact or system key; the
phases, each by one agent in turn. Earlier phases' files are in the working tree, uncommitted: NEVER commit,
push, stash, checkout or reset.>

## Rules (the user's documented preferences)
- <Conventions: simplicity, comment style, pinning, licences.>
- Do NOT change <framework files>. If a change there is unavoidable, STOP and report the exact proposal. <Where
  helpers may live instead.>
- Edit only <the files this job owns>; leave <files others own> alone.
- <Environment traps: shell aliases, cp/stat/sed flavours, container mounts, wait idioms.>

## Build and test
- <The build command; run it in the background and wait on the PID.>
- <HAZARDS: shared state that two builds corrupt (never two at once); stale archives (delete the archive of a
  changed recipe).>
- <The harness (qemu-check), devices to emulate, what cannot be tested: real keys, PINs.>
- <Checks every package passes: libraries, RPATHs, architecture, warnings.>

## Timebox and fallback (risky phases)
After <N> distinct failed approaches STOP: restore shared files so the earlier phases still build, keep your
recipes as a record of the attempt, and report what blocks, with evidence and the best next idea.

## Reporting
At most 300 words: what works (a command and one line of output each), files changed, proposals NOT carried out,
what the next phase must know, what you could not verify. No pasted logs. Append lessons to the section below.

## Notes for later phases
(agents append here)
