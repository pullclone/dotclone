# Research Template (Opt-In)

This template provides a lightweight, self-contained research playground
for ad-hoc experiments. It stays **decoupled** from the NyxOS system
flake and ships its own pinned inputs, devshell, and helper scripts so
you can iterate without impure evaluation or host coupling.

## Layout

- `flake.nix` — pinned nixpkgs with a Python devShell and `nix run`
  entrypoint.
- `data/metadata.yaml` — dataset description (source, version, schema).
- `data/checksums.sha256` — optional integrity manifest placeholder.
- `scripts/verify-data.sh` — quick validation that metadata is present
  and parseable.
- `scripts/gen-checksums.sh` — hash files under `data/raw/` into
  `data/checksums.sha256`.
- `scripts/log-run.sh` — structured log header for each run.
- `scripts/run-exp.sh` — orchestrator that verifies data, logs, and
  dispatches experiments.
- `experiments/exp001/run.sh` — example experiment runner that defers to
  `src/your_code.py`.
- `src/your_code.py` — stub Python entrypoint that consumes metadata and
  emits a JSONL summary for each run.

## Quickstart

```bash
# enter the pinned dev environment (python + linting tools)
nix develop ./templates/research

# run the example experiment (writes run output under ./runs/)
nix run ./templates/research#run -- exp001

# optional: validate metadata only
./templates/research/scripts/verify-data.sh
```

## Notes

- The template is standalone and will not import NyxOS system modules.
- Checks are **opt-in**; repository CI does not gate on template
  evaluation. Use `just audit-templates` when you want to validate it.

## Data Policy (Template)

- Raw data lives outside the Nix store; keep it under `data/raw/` and
  track integrity via `metadata.yaml` + `checksums.sha256`.
- For large datasets, store artifacts externally (object storage,
  shared drive, or fetch-on-demand) and record provenance in metadata.
