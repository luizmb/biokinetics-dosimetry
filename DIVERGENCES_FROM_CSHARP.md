# Divergences from the C# reference (`frmCalculo.cs`)

This Swift port intentionally diverges from `ipen/Ipen.SSID.UI/frmCalculo.cs` in the following places. Every divergence below is a fix for a latent bug that exists in the C# but happens not to bite on the existing Uranium model. Keep this file in sync if any of these get touched.

## 1. `term` matrix is fully reset at the start of each `calculateStep`

**C# (`frmCalculo.cs:276-281`)** resets only `term[i,i] = 1`; off-diagonals retain whatever values they were left in by the previous call's Taylor loop.

**Swift** zeroes `term` completely before setting `term[i,i] = 1`, so the Taylor series always starts from the identity matrix as the algorithm requires.

**Impact in C#:** silently uses a non-identity starting `term` from the 3rd call onward (the first two happen to leave it clean because step 1 multiplies by `Tempo = 0` and produces an all-zero `term`). Small but compounding error on long integrations.

## 2. Convergence check uses `abs()`

**C# (`frmCalculo.cs:328`)** compares `term[i,j] / sum[i,j] > terr` without `abs()`. With a fixed `terr = 1e-10`, any negative ratio is treated as "converged."

**Swift** uses `abs(term[i,j] / sum[i,j]) > tolerance`.

**Impact in C#:** for any compartmental system whose matrix has only non-positive entries off the convergence path (e.g. a single radioactive compartment with no transfers in or out, or any system where every relevant ratio happens to be negative on the first Taylor term), the loop exits after one iteration and returns `sum = I + A` — a 1st-order Taylor truncation instead of the converged matrix exponential. The single-compartment radioactive-decay analytic test (`AnalyticDecayTests.testSingleCompartmentRadioactiveDecay`) flushes this out: without `abs()`, the answer is `1 - λt` instead of `e^{-λt}`.

## 3. Particular-solution block removed

**C# (`frmCalculo.cs:363-383`)** computes `u[i] = λ · qi · (sum − I) · xo` after the homogeneous solve, then never reads `u` anywhere else. The Birchall algorithm includes this term for chronic-source problems; the C# UI doesn't expose any chronic-source input, so it's pure dead weight that drags along an `Inversao()` routine and the `q`/`qi` work matrices.

**Swift** omits the whole block, along with `Inversao()`, `q`, `qi`, and the `u` array.

**Impact in C#:** none — `u` is discarded. The Swift removal is purely a cleanup.

---

## Decisions that match C# (worth noting)

- **λ = ln(2)/halfLife** — Swift uses `log(2)` (≈0.6931472); the C# Birchall path uses `Math.Log(2)`. The C# Numeric path (`frmCalculo.cs:811`) hardcodes `0.693` — a ~0.021% drift. When the Swift Numeric path ships, it will use `log(2)` (the textbook-correct value), intentionally diverging from the C# Numeric path on that one constant.
- **Time / step / final as `Int` days** — matches C#.
- **Initial conditions encoded in `R[i,i]`** — matches C# (`frmCalculo.cs:452`). The Phase A4 refactor may lift this into an explicit `[Double]`.
- **Scaling-and-squaring with threshold 0.2 and `terr = 1e-10`** — matches C# exactly.
