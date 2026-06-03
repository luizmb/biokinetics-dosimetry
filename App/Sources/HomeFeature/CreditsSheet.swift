import AppDomain
import SwiftUI
import UIComponents

// MARK: - CreditsSheet

struct CreditsSheet: View {
    var onDismiss: () -> Void

    @Environment(\.glassTokens) private var g

    var body: some View {
        NavigationStack {
            ZStack {
                GlassAppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Scientific References & Model Credits")
                        ForEach(scientificCredits) { item in
                            creditRow(item)
                        }

                        sectionHeader("Open Source Libraries")
                        ForEach(libraryCredits) { item in
                            creditRow(item)
                        }

                        Text("This app is a Swift translation and extension of the SSID project originally developed by Thiago Claro at IPEN‑CNEN/SP, São Paulo, Brazil.")
                            .font(.caption)
                            .foregroundStyle(g.faint)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Credits & Licenses")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(g.faint)
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 8)
    }

    private func creditRow(_ item: CreditItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(g.ink)
                Spacer()
                if let badge = item.license {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(g.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(g.accent.opacity(0.10), in: Capsule())
                }
            }
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(g.muted)
            }
            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(g.faint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Data

private struct CreditItem: Identifiable {
    let id = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))  // positional — forEach uses id field
    let title:    String
    let subtitle: String?
    let detail:   String?
    let license:  String?

    init(_ title: String, subtitle: String? = nil, detail: String? = nil, license: String? = nil) {
        self.title    = title
        self.subtitle = subtitle
        self.detail   = detail
        self.license  = license
    }
}

// Override Identifiable so each item is distinct despite same static UUID
extension CreditItem: Equatable {
    static func == (l: Self, r: Self) -> Bool { l.title == r.title }
}

private let scientificCredits: [CreditItem] = [
    CreditItem("ICRP Publications 56, 67, 69, 130–137",
               subtitle: "International Commission on Radiological Protection",
               detail: "Biokinetic models, transfer rates, and dosimetric methodology used in nuclear models.",
               license: nil),
    CreditItem("Leggett (1994)",
               subtitle: "Health Physics 67(6):589–610",
               detail: "Physiological systems model for uranium — basis for the ICRP 137 uranium systemic model."),
    CreditItem("Birchall (1986)",
               subtitle: "Health Physics 50(3):389–397",
               detail: "Scaling-and-squaring matrix-exponential algorithm implemented as the Birchall solver."),
    CreditItem("Dormand & Prince (1980)",
               subtitle: "J. Comput. Appl. Math. 6(1):19–26",
               detail: "Dormand-Prince RK4(5) adaptive solver underlying the RK45 solver path."),
    CreditItem("Rabinowitz et al. (1976)",
               subtitle: "Science 182:81–83",
               detail: "Three-pool lead toxicokinetic model (blood / bone / soft tissue)."),
    CreditItem("WHO/IPCS EHC 101 (1990)",
               subtitle: "World Health Organization",
               detail: "Environmental Health Criteria for methylmercury; basis for the mercury toxicokinetic model."),
    CreditItem("Sheiner et al. (1979)",
               subtitle: "Clin. Pharmacol. Ther. 25:226–235",
               detail: "Two-compartment pharmacokinetic model for digoxin."),
    CreditItem("Thiago Claro / IPEN‑CNEN/SP",
               subtitle: "MSc Thesis, Universidade de São Paulo, 2011",
               detail: "Original SSID (Smart Software for Internal Dosimetry) C# codebase from which this app is derived. github.com/tclaro/ipen"),
]

private let libraryCredits: [CreditItem] = [
    CreditItem("SwiftRex",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Unidirectional data-flow state management framework.",
               license: "Apache 2.0"),
    CreditItem("FP",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Functional programming primitives, lenses, prisms, and DeferredTask.",
               license: "Apache 2.0"),
    CreditItem("SwiftCalx",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Numerical building blocks: Matrix, Taylor exponential, RK4/RK45, AcceleratedVector.",
               license: "MIT"),
    CreditItem("NetworkTools",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "DataDecoderFactory protocol used for XML and JSON import."),
    CreditItem("XMLCoder",
               subtitle: "© Shawn Moore & XMLCoder contributors",
               detail: "XML ↔ Codable bridge used for IPEN XML model import.",
               license: "MIT"),
]
