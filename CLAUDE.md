# CLAUDE.md — BiokineticsDosimetry

Biokinetics/dosimetry compartmental modelling. Integrates `dx/dt = A·x` (see
`Sources/Solver/CoefficientMatrix.swift`, `LinearSystem.swift`, `Solve.swift`,
`Birchall.swift`) using **SwiftCalx**'s `RungeKutta` solvers over `Math`'s vector
types. Depends on the published packages `FP` (`from: "3.0.0"`) and `SwiftCalx` (`from: "1.1.1"`).

## Performance — read before any perf work

This package is a **cross-package consumer of SwiftCalx's generic solvers**
(`RungeKutta4`/`RungeKutta45`, generic over `VectorState`). That is exactly the
scenario where a missing-specialization problem bites:

- **Generic + cross-module + hot path that isn't `@inlinable` is never specialized.**
  The per-stage `+`/`*` along the integration trajectory then stay indirect
  protocol-witness calls and the optimizer can't eliminate per-stage `[Double]`
  allocations. (Full story: FP's `IdentifiedArray` work, PR #73 — a handful of
  `@inlinable` annotations gave ~14× there.)
- SwiftCalx 1.0.0 ships `@inlinable` solver hot paths, so they specialize here. Moving from
  SwiftCalx 0.6 / FP 2.2 to 1.0 / 3.0 measured (Uranium model, p50): Birchall perTime 100 days
  524 ms → 1 ms, semigroup 1000 days 125 ms → 0.33 ms, RK4 (h=0.01) 100 days 1.18 s → 25 ms from the bump, then 69 µs through SwiftCalx 1.1's linear RK4 propagator,
  RK45 100 days 16 ms → 4.7 ms. See `../SwiftCalx/docs/PERFORMANCE.md` for the analysis.

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
