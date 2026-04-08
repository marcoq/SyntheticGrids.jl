# Upgrading SyntheticGrids.jl

This project now targets modern Julia and dependency versions.

## Baseline

- Julia: `1.10` and newer (`1.12` tested in CI)
- Regular CI excludes optional Python/pandapower integration tests

## Repeatable Upgrade Flow

1. Update to latest package versions allowed by `Project.toml` compat:

   ```bash
   julia --project=. scripts/upgrade.jl
   ```

2. If resolution fails:

   - Widen narrow `[compat]` entries in `Project.toml`.
   - Re-run `scripts/upgrade.jl`.

3. Validate locally on the target Julia version:

   ```bash
   julia +1.12 --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
   ```

4. Validate pandapower integration when needed:

   ```bash
   SYNTHETICGRIDS_RUN_PANDAPOWER_TESTS=true julia --project=. -e 'using Pkg; Pkg.test()'
   ```

## CI and Automation

- GitHub Actions CI matrix runs on Linux, macOS, and Windows for Julia `1.10`, `1.12`, and `nightly`.
- CompatHelper opens automated PRs for dependency compat updates.

## One-Time Repository Setup

To allow CompatHelper PRs from a bot identity, add this repository secret:

- `COMPATHELPER_PRIV`: SSH private key for a machine user with repo write access.

If this is not configured, CompatHelper can still run but may be unable to open PRs.
