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

    @ViewBuilder
    private func creditRow(_ item: CreditItem) -> some View {
        let content = VStack(alignment: .leading, spacing: 3) {
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
                if item.url != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundStyle(g.faint)
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

        if let url = item.url {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}

// MARK: - Data model

private struct CreditItem: Identifiable {
    let id:       String   // unique — used by ForEach
    let title:    String
    let subtitle: String?
    let detail:   String?
    let license:  String?
    let url:      URL?

    init(_ id: String, _ title: String,
         subtitle: String? = nil, detail: String? = nil,
         license: String? = nil, urlString: String? = nil) {
        self.id       = id
        self.title    = title
        self.subtitle = subtitle
        self.detail   = detail
        self.license  = license
        self.url      = urlString.flatMap(URL.init(string:))
    }
}

// MARK: - Content

private let scientificCredits: [CreditItem] = [
    CreditItem("icrp",
               "ICRP Publications 56, 67, 69, 130–137",
               subtitle: "International Commission on Radiological Protection",
               detail: "Biokinetic models, transfer rates, and dosimetric methodology used in nuclear models.",
               urlString: "https://www.icrp.org/publications.asp"),

    CreditItem("leggett1994",
               "Leggett (1994) — Uranium Systemic Model",
               subtitle: "Health Physics 67(6):589–610",
               detail: "Physiological systems model for uranium — basis for the ICRP 137 uranium systemic model.",
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=leggett+uranium+physiological+1994"),

    CreditItem("birchall1986",
               "Birchall (1986) — Scaling-and-Squaring Solver",
               subtitle: "Health Physics 50(3):389–397",
               detail: "Matrix-exponential algorithm for compartmental radionuclide models. Implemented here as the Birchall solver.",
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=birchall+microcomputer+compartmental+radionuclide+1986"),

    CreditItem("dormandprince1980",
               "Dormand & Prince (1980) — RK45",
               subtitle: "J. Comput. Appl. Math. 6(1):19–26",
               detail: "Dormand-Prince embedded Runge-Kutta pair underlying the adaptive RK45 solver path.",
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=dormand+prince+runge-kutta+1980"),

    CreditItem("rabinowitz1976",
               "Rabinowitz et al. (1976) — Lead Model",
               subtitle: "J. Clin. Invest. 57(1):68–73",
               detail: "Three-pool lead toxicokinetic model (blood / bone / soft tissue) validated with stable isotope tracers.",
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=rabinowitz+lead+kinetic+analysis+1976"),

    CreditItem("whomercury1990",
               "WHO/IPCS EHC 101 (1990) — Methylmercury",
               subtitle: "World Health Organization",
               detail: "Environmental Health Criteria for methylmercury; basis for the mercury toxicokinetic model.",
               urlString: "https://www.who.int/publications/i/item/environmental-health-criteria-101-methylmercury"),

    CreditItem("sheiner1979",
               "Digoxin 2-Compartment PK",
               subtitle: "Standard clinical pharmacokinetics literature",
               detail: "Two-compartment intravenous model for digoxin with large volume of distribution and slow peripheral equilibration.",
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=digoxin+two-compartment+pharmacokinetics"),

    CreditItem("tclaro2011",
               "Thiago Claro / IPEN‑CNEN/SP",
               subtitle: "MSc Thesis, Universidade de São Paulo, 2011",
               detail: "Original SSID (Smart Software for Internal Dosimetry) C# codebase from which this app is derived.",
               urlString: "https://github.com/tclaro/ipen"),
]

private let libraryCredits: [CreditItem] = [
    CreditItem("swiftrex",
               "SwiftRex",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Unidirectional data-flow state management framework.",
               license: "Apache 2.0",
               urlString: "https://github.com/SwiftRex/SwiftRex"),

    CreditItem("fp",
               "FP",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Functional programming primitives, lenses, prisms, and DeferredTask.",
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/FP"),

    CreditItem("swiftcalx",
               "SwiftCalx",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "Numerical building blocks: Matrix, Taylor exponential, RK4/RK45, AcceleratedVector.",
               license: "MIT",
               urlString: "https://github.com/luizmb/SwiftCalx"),

    CreditItem("networktools",
               "NetworkTools",
               subtitle: "© Luiz Rodrigo Martins Barbosa",
               detail: "DataDecoderFactory protocol used for XML and JSON import.",
               urlString: "https://github.com/luizmb/NetworkTools"),

    CreditItem("xmlcoder",
               "XMLCoder",
               subtitle: "© Shawn Moore & XMLCoder contributors",
               detail: "XML ↔ Codable bridge used for IPEN XML model import.",
               license: "MIT",
               urlString: "https://github.com/CoreOffice/XMLCoder"),
]
