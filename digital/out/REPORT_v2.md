# Station – UUL-EXTRA Digital Factory Pack v2

## What is real now (not ideas)
- Digital identity files + chat tree + env matrix
- Backend module `uul_core` with:
  - /uul/factory/run
  - /uul/factory/status
  - /uul/tasks/submit
  - /uul/tasks/next
  - /uul/tasks/report
  - /uul/tasks/recent
- Runner Loop 4 script:
  - `station_runner_loop4_uul.sh` polls tasks and executes them locally, then reports results.

## Your "Loop" model (digital)
UI -> backend submit task -> Loop4 runner executes in Termux -> reports -> (next step Loop5 push GitHub) -> (Loop6 Render auto deploy)

## Next steps
1) Restart backend to load new routes
2) Run factory smoke
3) Start Loop4 runner
4) Submit tasks via /uul/tasks/submit (from UI or curl)
