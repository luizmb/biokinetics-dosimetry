# Biokinetics & Dosimetry

A Swift library for building and numerically solving **compartmental biokinetic models** — the mathematical framework used in radiation dosimetry, pharmacokinetics, toxicokinetics, and environmental fate modelling.

Define any network of compartments and first-order transfer rates (in XML or in Swift), select a solver, and get the time-evolution of compartment activities across the full integration horizon.

---

## Background

### What is a compartmental biokinetic model?

A compartmental model partitions a biological system (a human body, an ecosystem, a pharmacological experiment) into discrete **compartments** — organs, tissue pools, blood fractions, excretion pathways — and describes how a substance flows between them. Each flow is governed by a first-order transfer rate constant `k` (units: day⁻¹), meaning the rate of transfer from compartment `i` to compartment `j` is proportional to the current amount in `i`:

```
dxⱼ/dt = Σᵢ kᵢⱼ · xᵢ  −  Σⱼ kⱼᵢ · xᵢ
```

When all compartments are assembled, the full system becomes a linear matrix ODE:

```
dx/dt = A · x,   x(0) = x₀
```

where `A` is the **coefficient matrix** (also called the transfer-rate matrix), constructed as:

- **Off-diagonal** `A[j, i] = kᵢⱼ` — the rate flowing *into* compartment `j` from compartment `i`
- **Diagonal** `A[i, i] = −λ − Σⱼ kᵢⱼ` — the sum of all outflows from compartment `i`, plus radioactive decay `λ = ln(2) / t½`

The exact solution is the **matrix exponential**:

```
x(t) = e^(At) · x₀
```

### Fields that use this model

| Field | What is being modelled |
|---|---|
| **Radiation dosimetry** | Radionuclide activity in organs over time after intake |
| **Pharmacokinetics (PK)** | Drug concentration in plasma, tissues, organs |
| **Toxicokinetics** | Distribution and elimination of environmental toxins |
| **Epidemiology** | Compartmental SIR/SEIR epidemic spread models |
| **Ecology** | Bioaccumulation of pollutants through food chains and ecosystems |
| **Environmental chemistry** | Carbon and nitrogen cycling, contaminant fate in soils and water |

The mathematical structure — nodes, directed edges, first-order rates, linear ODE system — is identical across all of them.

---

## Architecture

```
BiokineticsDosimetry
│
├── CompartmentalModel           — the model (compartments + connections + matrix builder)
├── Compartment                  — a single node (id, name, intake flag, initial fraction, …)
├── CompartmentConnection        — a directed edge with a transfer rate (day⁻¹)
│
├── InternalDosimetryCalculator  — orchestrates time discretisation, solver dispatch,
│                                   and concurrency
│
├── SolverMethod                 — enum selecting which algorithm to use
│   ├── .birchall(composition:)  — matrix-exponential via scaling-and-squaring (Birchall 1986)
│   │   ├── .perTime             — independent e^(t·A)·x₀ per output row, parallelised
│   │   └── .semigroup           — one e^(step·A) then iterated mat-vec, sequential
│   ├── .rungeKutta4(stepSize:)  — classical fixed-step RK4
│   └── .rungeKutta45(tolerance:)— adaptive Dormand-Prince RK45
│
├── Birchall                     — scaling-and-squaring matrix-exponential algorithm
│
└── CompartmentalModelLoader     — loads a model from XML (see XML format below)
```

The package depends on [SwiftCalx](https://github.com/luizmb/SwiftCalx) for the underlying numerical building blocks (`Matrix`, `Taylor.exponential`, `RungeKutta4`, `RungeKutta45`, `AcceleratedVector`) and on [FP](https://github.com/luizmb/FP.git) for functional primitives and lenses.

---

## Solvers

### Birchall — Scaling-and-Squaring Matrix Exponential

Named after **A. Birchall**'s 1986 paper *"A microcomputer algorithm for solving compartmental models involving radionuclide transformations"* (Health Physics 50(3): 389–397).

**Why not a plain Taylor series?**
The straight Taylor series `e^A = I + A + A²/2! + A³/3! + …` works in theory for any square matrix but fails numerically for matrices with large-magnitude entries: intermediate terms grow huge before the factorial tames them, and catastrophic cancellation destroys accuracy.

**The trick — exploit the identity** `e^A = (e^(A/2^k))^(2^k)`:

1. **Choose a scaling power `k`** such that the most-negative diagonal of `A/2^k` falls below `0.2` (Birchall's heuristic). Diagonals dominate the spectrum of a compartmental matrix because they encode `−λ − Σ outflow`.
2. **Form the scaled matrix** `Aₛ = A / 2^k`.
3. **Taylor-expand `e^Aₛ`** using `Taylor.exponential(of:tolerance:maxIterations:)` from SwiftCalx. The scaled matrix is small enough for accurate convergence.
4. **Square `k` times** via `Matrix.squared(times:)` to recover `e^A = (e^Aₛ)^(2^k)`.

This matches the original Birchall algorithm exactly (threshold `0.2`, tolerance `1e-10`).

**Two composition modes:**

| Mode | Algorithm | Cost | Parallelism |
|---|---|---|---|
| `.perTime` | Fresh `e^(t·A)` per output row | O(n) matrix exponentials | ✅ `withTaskGroup` — fans out over all CPU cores |
| `.semigroup` | One `e^(step·A)`, then `n` mat-vecs | 1 matrix exponential + n mat-vecs | ❌ Sequential (each step depends on previous) |

The `.perTime` mode is numerically independent per row (no drift), while `.semigroup` is ~60× faster on large horizons at the cost of small floating-point drift for stiff or long integrations.

**Accuracy:** The Swift port of the ICRP Uranium-238 biokinetic model (19 compartments, 1000-day integration) agrees with the original C# reference to `1e-12` per element — see `UraniumGoldenTests`.

### Runge-Kutta 4 (RK4)

Classical fourth-order fixed-step method. Each output sample requires `(step / h)` sub-steps of size `h`. Good general-purpose accuracy for smooth systems with modest stiffness.

```swift
.rungeKutta4(stepSize: 0.01)   // 0.01-day sub-steps
```

### Runge-Kutta 4(5) / Dormand-Prince (RK45)

Adaptive-step method with embedded error control. Automatically adjusts step size to maintain a user-specified tolerance. Efficient when accuracy requirements are tight or when the system has variable stiffness across time.

```swift
.rungeKutta45(tolerance: 1e-10)
```

Both RK methods route the state vector through `AcceleratedVector`, so every per-stage `+` and scalar `·` is dispatched through Apple's **vDSP** (Accelerate framework) on Apple platforms — zero-overhead, hardware-vectorised arithmetic.

---

## Usage

### 1. Define a model in Swift

```swift
import BiokineticsDosimetry

// A simple two-compartment system: substance transfers from blood → tissue
let model = CompartmentalModel(
    compartments: [
        Compartment(id: "a", name: "Blood", follow: true, intake: true, dispose: false, fraction: 1.0),
        Compartment(id: "b", name: "Tissue", follow: true, intake: false, dispose: false, fraction: 0.0)
    ],
    connections: [
        CompartmentConnection(from: "a", to: "b", rate: 0.1)  // 0.1 day⁻¹
    ]
)
```

### 2. Create a calculator and run it

```swift
let calculator = InternalDosimetryCalculator(
    step: 1,          // output every 1 day
    halfLife: 0,      // no radioactive decay (set to half-life in days for radionuclides)
    final: 50,        // integrate over 50 days
    solver: .birchall // default; also .rungeKutta4(stepSize:) or .rungeKutta45(tolerance:)
)

// calculate(model:) returns a DeferredTask — nothing runs until .run()
let trajectory = await calculator.calculate(model: model).run()

// trajectory[t][compartmentIndex]
let bloodAt10Days    = trajectory[10][0]  // fraction remaining in blood at t = 10 days
let tissueAt10Days   = trajectory[10][1]  // fraction in tissue at t = 10 days
```

### 3. Load a model from XML

```swift
import XMLCoder
import BiokineticsDosimetry

let xmlData = try Data(contentsOf: URL(fileURLWithPath: "Uranium.xml"))
let model = try loadCompartmentalModel(using: XMLDecoder())(xmlData).get()

// Set the intake compartment and initial fraction
let readyModel = model.updatingCompartment(id: "4") {
    $0.with(intake: true, fraction: 1.0)
}

let calculator = InternalDosimetryCalculator(
    step: 1,
    halfLife: 1_642_500_000_000,  // U-238: 4.5 × 10⁹ years in days
    final: 1000,
    solver: .birchall(composition: .semigroup)  // fast path for long horizons
)

let trajectory = await calculator.calculate(model: readyModel).run()
```

### 4. Solver selection guide

| Scenario | Recommended solver |
|---|---|
| Default / best accuracy | `.birchall` (`.perTime`) |
| Long horizon (> 500 steps), speed/accuracy trade-off acceptable | `.birchall(.semigroup)` |
| Verification / cross-check against Birchall | `.rungeKutta45(tolerance: 1e-10)` |
| Teaching / simplest explicit method | `.rungeKutta4(stepSize: 0.01)` |

---

## XML Model Format

Models can be serialised as XML using the schema from the original C# IPEN codebase. The loader reads two tables:

### `TableCaixas` — Compartments

| Field | Type | Description |
|---|---|---|
| `Numero` | Int | Compartment number (used as ID) |
| `Nome` | String | Human-readable name |
| `Acompanhar` | Bool | Whether to include this compartment in the tracked output |
| `Eliminacao` | Bool | Whether this is an excretion/elimination compartment |

Visual layout fields (`PosLeft`, `PosTop`, `PosWidth`, `PosHeight`, `CorR`, `CorG`, `CorB`) are parsed but reserved for future UI use.

### `TableLinhas` — Connections

| Field | Type | Description |
|---|---|---|
| `CaixaInicio` | Int | Source compartment number |
| `CaixaFim` | Int | Destination compartment number |
| `ValorAB` | Float | Transfer rate A → B (day⁻¹) |
| `ValorBA` | Float | Transfer rate B → A (day⁻¹); `0` means unidirectional |

A single `<TableLinhas>` element with `ValorBA > 0` generates **two** `CompartmentConnection` objects (bidirectional).

### Example — Uranium-238 ICRP Biokinetic Model

The included `Uranium.xml` fixture encodes the ICRP systemic model for Uranium-238 with 19 compartments:

```
Rapid Turnover (ST0) ⇄ Plasma ⇄ Intermediate Turnover (ST1)
                              ⇄ Slow Turnover (ST2)
                              ⇄ Cortical Surface / Volume (bone)
                              ⇄ Trabecular Surface / Volume (bone)
                              → Liver 1 ⇄ Liver 2
                              → GI Tract Contents → Faeces
                              ⇄ Other Kidney Tissue
                              → Urinary Path → Urinary Bladder Contents → Urine
                              ⇄ RBC
```

Bone is modelled with surface, volume-exchange, and volume-no-exchange sub-compartments for both cortical and trabecular bone, reflecting the slow remodelling kinetics of uranium in skeletal tissue.

---

## Mathematical Reference

### The coefficient matrix

For a model with `n` compartments and radioactive decay constant `λ = ln(2) / t½`:

```
        ⎧ kᵢⱼ                      if i ≠ j  (transfer from j into i)
A[i,j] = ⎨
        ⎩ −λ − Σⱼ≠ᵢ kⱼᵢ           if i = j  (total outflow from i, plus decay)
```

The solution is:

```
x(t) = e^(At) · x₀
```

### Bateman equations (closed form for chain models)

For a linear serial chain A → B → C with rates k₁ and k₂ (no radioactive decay), the Bateman equations give closed-form solutions:

```
xₐ(t) = e^(−k₁t)
x_b(t) = k₁/(k₂ − k₁) · (e^(−k₁t) − e^(−k₂t))
x_c(t) = 1 − xₐ(t) − x_b(t)
```

These are used as ground-truth reference values in the test suite to validate all four solver paths independently.

---

## Testing

```bash
swift test                    # ~2s — all tests except the slow golden test
RUN_GOLDEN=1 swift test       # also runs UraniumGoldenTests (~220s debug, ~20s release)
```

| Test suite | What it verifies |
|---|---|
| `AnalyticDecayTests` | Birchall vs closed-form Bateman; single-compartment radioactive decay |
| `BirchallTests` | Unit tests for scaling-and-squaring: zero matrix → identity, diagonal matrices, large-magnitude matrices, scaling power heuristic |
| `CrossSolverTests` | All four solvers (Birchall `.perTime`, `.semigroup`, RK4, RK45) vs Bateman solutions and vs each other on the real Uranium model |
| `CompartmentalModelLoaderTests` | XML parsing, coefficient matrix construction, initial condition encoding |
| `UraniumGoldenTests` | Full 1000-day U-238 trajectory against C# reference (`uranium_birchall_golden.json`), tolerance `1e-12` |
| `SolverBenchmarks` | Performance baselines for the four solver paths |

### Generating a fresh golden fixture

The [`ipen-validator`](../ipen-validator) project is a .NET 8 console port of the C# Birchall routine (with two latent C# bugs fixed — see [DIVERGENCES_FROM_CSHARP.md](DIVERGENCES_FROM_CSHARP.md)):

```bash
cd ipen-validator
dotnet run -- \
  --xml ../ipen/Database/Uranium.xml \
  --intake 4 --fraction 1 \
  --half-life 1642500000000 \
  --step 1 --final 1000 \
  --out ../BiokineticsDosimetry/Tests/BiokineticsDosimetryTests/Fixtures/uranium_birchall_golden.json
```

---

## Known Divergences from the C# Reference

See [DIVERGENCES_FROM_CSHARP.md](DIVERGENCES_FROM_CSHARP.md) for the full list. The two material differences are both **bug fixes**:

1. **Taylor series starting matrix** — The C# code does not fully reset the `term` matrix between calls; off-diagonal values leak from one Taylor evaluation into the next. Swift zeroes the matrix completely so the series always starts from the correct identity.
2. **Convergence check uses `abs()`** — The C# check `term/sum > tolerance` without `abs()` treats any negative ratio as "converged", causing a 1st-order Taylor truncation on certain systems (e.g. a single decaying compartment). Swift uses `abs(term/sum) > tolerance`.

Both fixes are applied identically in the Swift library and in `ipen-validator`, so the golden test is a true cross-language comparison.

---

## Package Dependencies

| Package | Used for |
|---|---|
| [SwiftCalx](https://github.com/luizmb/SwiftCalx) | `Matrix`, `Taylor.exponential`, `RungeKutta4`, `RungeKutta45`, `AcceleratedVector` (vDSP) |
| [FP](https://github.com/luizmb/FP.git) | Functional primitives, lenses (`@Lenses`), `DeferredTask`, `Convert` |
| [NetworkTools](https://github.com/luizmb/NetworkTools.git) | `DataDecoderFactory` protocol for the XML loader |
| [XMLCoder](https://github.com/CoreOffice/XMLCoder) | XML ↔ `Decodable` bridge |

---

## References

### Primary algorithm

**Birchall, A. (1986).** *A microcomputer algorithm for solving compartmental models involving radionuclide transformations.* Health Physics, 50(3), 389–397.

The paper that defines this library's primary solver. Birchall adapted the classical scaling-and-squaring method for the specific structure of radionuclide compartmental matrices — strongly negative diagonals, non-negative off-diagonals — and introduced the `< 0.2` threshold heuristic implemented here exactly.

**Moler, C., & Van Loan, C. (2003).** *Nineteen dubious ways to compute the exponential of a matrix, twenty-five years later.* SIAM Review, 45(1), 3–49. [doi:10.1137/S00361445024180](https://doi.org/10.1137/S00361445024180)

The definitive survey of matrix-exponential algorithms. Section 3 covers scaling-and-squaring and provides the numerical-stability analysis that explains why Birchall's heuristic works.

### Thesis and institutional work (origins of this codebase)

**Claro, T. (2011).** *Desenvolvimento de programa computacional para cálculo de dosimetria interna baseado em modelos multicompartimentais.* Dissertação de mestrado, Instituto de Pesquisas Energéticas e Nucleares (IPEN-CNEN/SP), Universidade de São Paulo. [teses.usp.br](http://www.teses.usp.br/teses/disponiveis/85/85131/tde-20122011-090939/pt-br.php)

The original C# implementation at [github.com/tclaro/ipen](https://github.com/tclaro/ipen) originates from this MSc thesis. Claro developed the compartmental model editor and Birchall solver as a computational tool for internal dosimetry at IPEN-CNEN/SP, implementing the ICRP biokinetic models for radionuclides including Uranium-238. This Swift library is a direct descendant of that work.

**Loch, G. G. (2016).** *Versão corrigida.* Dissertação, Instituto de Física, Universidade de São Paulo. [teses.usp.br](https://teses.usp.br/teses/disponiveis/45/45132/tde-25082016-221140/publico/Guilherme_Galina_Loch_Versao_Corrigida.pdf)

Further computational work in biokinetic modelling and dosimetry in the same institutional context.

### ICRP biokinetic models

**ICRP Publication 69 (1995).** *Age-dependent doses to members of the public from intake of radionuclides: Part 3. Ingestion dose coefficients.* Annals of the ICRP, 25(1).

Defines the systemic biokinetic model for uranium used in the `Uranium.xml` fixture, including the bone sub-compartments (cortical/trabecular surface and volume-exchange pools) that reflect the slow remodelling kinetics of uranium in skeletal tissue.

**ICRP Publication 130 (2015).** *Occupational intakes of radionuclides: Part 1.* Annals of the ICRP, 44(2).

The current ICRP framework for internal dosimetry, presenting updated compartmental biokinetic models for inhalation and ingestion pathways.

### Numerical methods background

**Bateman, H. (1910).** *The solution of a system of differential equations occurring in the theory of radio-active transformations.* Proceedings of the Cambridge Philosophical Society, 15, 423–427.

The Bateman equations — closed-form solutions for linear serial compartment chains — are used in this library's test suite as ground-truth reference values to validate all four solver paths independently.

**Dormand, J. R., & Prince, P. J. (1980).** *A family of embedded Runge-Kutta formulae.* Journal of Computational and Applied Mathematics, 6(1), 19–26.

The Dormand-Prince pair underlying the `rungeKutta45` adaptive solver in SwiftCalx.

---

## Acknowledgements

This library is a Swift translation and refactor of the C# SSID project by [Thiago Claro](https://github.com/tclaro), originally developed at [IPEN-CNEN/SP](https://www.ipen.br) (Instituto de Pesquisas Energéticas e Nucleares, São Paulo, Brazil) as part of his MSc thesis under the nuclear engineering faculty at USP. The mathematical model, compartment structure, and XML schema are derived from that work.
