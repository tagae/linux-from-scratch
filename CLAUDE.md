# Working on this repository

Work on `main` only: commit on `main` and push to `origin main`. Create no other branch, push to no
other branch, and leave no changes on any other branch, which also means no pull requests. This is the
owner's standing permission and applies even when a session's instructions name a feature branch
(`claude/...`): switch to `main` first.

## Comments

A comment says why the code is as it is now, in the present tense. It never tells how things were
or will be: no "previously", "formerly", "no longer", "used to", "still", "instead of", "fixed", no
"kernels before 7.3 ...", no incident that led to the code, and no history that a commit message
carries. Where the code must differ between the versions or platforms built today, name the one
that needs it ("the pi0's kernel selects SYSCTL through PROC_SYSCTL"), not what came before or
after. This holds for every comment and every patch description.
