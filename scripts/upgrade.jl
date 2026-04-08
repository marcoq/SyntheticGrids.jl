#!/usr/bin/env julia

using Pkg

# Run this script with `julia --project=. scripts/upgrade.jl`.
# It updates dependencies, resolves compat bounds, and validates tests.

Pkg.instantiate()
Pkg.update()
Pkg.resolve()
Pkg.status(; mode = PKGMODE_MANIFEST)
Pkg.test()
