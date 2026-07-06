# CLAUDE.md — BiokineticsDosimetry

Biokinetics/dosimetry compartmental modelling. Integrates `dx/dt = A·x` (see
`Sources/Solver/CoefficientMatrix.swift`, `LinearSystem.swift`, `Solve.swift`,
`Birchall.swift`) using **SwiftCalx**'s `RungeKutta` solvers over `Math`'s vector
types. Depends on the published packages `FP` and `SwiftCalx` (`from: "0.3.0"`).

## Performance — read before any perf work

This package is a **cross-package consumer of SwiftCalx's generic solvers**
(`RungeKutta4`/`RungeKutta45`, generic over `VectorState`). That is exactly the
scenario where a missing-specialization problem bites:

- **Generic + cross-module + hot path that isn't `@inlinable` is never specialized.**
  The per-stage `+`/`*` along the integration trajectory then stay indirect
  protocol-witness calls and the optimizer can't eliminate per-stage `[Double]`
  allocations. (Full story: FP's `IdentifiedArray` work, PR #73 — a handful of
  `@inlinable` annotations gave ~14× there.)
- SwiftCalx currently has **no `@inlinable`/`@_specialize`** on its solver hot
  paths. See `SwiftCalx/docs/PERFORMANCE.md` (sibling repo at
  `../SwiftCalx/docs/PERFORMANCE.md`) for the analysis and the fix.
- **Caveat for this repo:** Biokinetics pins SwiftCalx by published version
  (`from: "0.3.0"`), so the solver-specialization win only reaches here once
  SwiftCalx ships a release with it. Until then, a local `@_specialize` or an
  `@inlinable` wrapper around the integration call in this package can recover some
  of it for the concrete state type used here.

Local hot paths worth auditing the same way:
- `Sources/Solver/Solve.swift` — the integration driver loop.
- `Sources/Solver/CoefficientMatrix.swift` / `LinearSystem.swift` — matrix build &
  apply; check for hand-rolled `map`/`zip` loops that could use BLAS/vDSP or
  `withUnsafeBufferPointer`.

**Measure first.** No benchmark suite here yet. Before optimizing, stand up a
nested `package-benchmark` package (recipe in `../SwiftCalx/docs/PERFORMANCE.md`)
with `.mallocCountTotal`, exclude setup via `benchmark.startMeasurement()`, and
compare saved baselines. Trust deterministic malloc counts over noisy wall-clock;
use within-run ratios and confirm on CI; remember `--filter` is a regex that
silently matches nothing if mistyped.

## Build & test
SwiftPM (`swift build` / `swift test`). See `README.md` and
`DIVERGENCES_FROM_CSHARP.md` for domain context.
