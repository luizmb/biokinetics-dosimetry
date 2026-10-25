import AppDomain
import SwiftUI
import Localization
import Vitral

// MARK: - CreditsSheet

struct CreditsSheet: View {
    /// The screen's appearance, from its parent's view state.
    let colorScheme: ColorScheme
    var onDismiss: () -> Void


    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader(L.Credits.scientific)
                        ForEach(scientificCredits) { item in
                            creditRow(item)
                        }

                        sectionHeader(L.Credits.libraries)
                        ForEach(libraryCredits) { item in
                            creditRow(item)
                        }

                        Text(L.Credits.ssidStatement)
                            .font(.caption)
                            .foregroundStyle(Color(.inkFaint, scheme: colorScheme))
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(L.Credits.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.done, action: onDismiss)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(TypeToken.sectionLabel)
            .kerning(0.5)
            .foregroundStyle(Color(.inkFaint, scheme: colorScheme))
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func creditRow(_ item: CreditItem) -> some View {
        let content = VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                item.title
                    .font(TypeToken.bodyStrong)
                    .foregroundStyle(Color(.ink, scheme: colorScheme))
                Spacer()
                if let badge = item.license {
                    Text(badge)
                        .font(TypeToken.codeSmall.weight(.medium))
                        .foregroundStyle(Color(.accent, scheme: colorScheme))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.accent, scheme: colorScheme).opacity(0.10), in: Capsule())
                }
                if item.url != nil {
                    Image(systemName: "arrow.up.right")
                        .font(TypeToken.sectionLabel.weight(.regular))
                        .foregroundStyle(Color(.inkFaint, scheme: colorScheme))
                }
            }
            if let subtitle = item.subtitle {
                subtitle
                    .font(TypeToken.detail)
                    .foregroundStyle(Color(.inkMuted, scheme: colorScheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let detail = item.detail {
                detail
                    .font(TypeToken.detail)
                    .foregroundStyle(Color(.inkFaint, scheme: colorScheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    let title:    Text
    let subtitle: Text?
    let detail:   Text?
    let license:  String?
    let url:      URL?

    /// Text, not strings: what is said about a work is translated, its name and where it was
    /// published are not.
    init(_ id: String, _ title: Text,
         subtitle: Text? = nil, detail: Text? = nil,
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
               Text(L.Credits.icrpTitle),
               subtitle: Text(L.Credits.icrpOrg),
               detail: Text(L.Credits.icrpDetail),
               urlString: "https://www.icrp.org"),

    CreditItem("leggett1994",
               Text(L.Credits.leggettTitle),
               subtitle: Text(verbatim: "Health Physics 67(6):589–610"),
               detail: Text(L.Credits.leggettDetail),
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=leggett+uranium+physiological+1994"),

    CreditItem("birchall1986",
               Text(L.Credits.birchallTitle),
               subtitle: Text(verbatim: "Health Physics 50(3):389–397"),
               detail: Text(L.Credits.birchallDetail),
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=birchall+microcomputer+compartmental+radionuclide+1986"),

    CreditItem("dormandprince1980",
               Text(L.Credits.dormandTitle),
               subtitle: Text(verbatim: "J. Comput. Appl. Math. 6(1):19–26"),
               detail: Text(L.Credits.dormandDetail),
               urlString: "https://doi.org/10.1016/0771-050X(80)90013-3"),

    CreditItem("rabinowitz1976",
               Text(L.Credits.rabinowitzTitle),
               subtitle: Text(verbatim: "J. Clin. Invest. 57(1):68–73"),
               detail: Text(L.Credits.rabinowitzDetail),
               urlString: "https://pubmed.ncbi.nlm.nih.gov/?term=rabinowitz+lead+kinetic+analysis+1976"),

    CreditItem("whomercury1990",
               Text(L.Credits.whoTitle),
               subtitle: Text(L.Credits.whoOrg),
               detail: Text(L.Credits.whoDetail),
               urlString: "https://inchem.org/documents/ehc/ehc/ehc101.htm"),

    CreditItem("sheiner1979",
               Text(L.Credits.digoxinTitle),
               subtitle: Text(L.Credits.digoxinSource),
               detail: Text(L.Credits.digoxinDetail),
               urlString: "https://en.wikipedia.org/wiki/Digoxin#Pharmacokinetics"),

    CreditItem("tclaro2011",
               Text(verbatim: "Thiago Claro — SSID"),
               subtitle: Text(L.Credits.claroThesis),
               detail: Text(L.Credits.claroDetail("\"Desenvolvimento de programa computacional para cálculo de dosimetria interna baseado em modelos multicompartimentais.\"")),
               urlString: "https://teses.usp.br/teses/disponiveis/85/85131/tde-20122011-090939/pt-br.html"),

    CreditItem("orlando2011",
               Text(verbatim: "Orlando Rodriguez Júnior — IPEN‑CNEN/SP"),
               subtitle: Text(L.Credits.orlandoSource),
               detail: Text(L.Credits.orlandoDetail),
               urlString: "https://repositorio.ipen.br/server/api/core/bitstreams/bc0b5a16-e4b3-4311-a862-145e39280026/content"),

]

private let libraryCredits: [CreditItem] = [
    CreditItem("ssid",
               Text(verbatim: "SSID/CBT — tclaro/ipen"),
               subtitle: Text(verbatim: "© Thiago Claro / IPEN‑CNEN/SP"),
               detail: Text(L.Credits.ssidDetail),
               urlString: "https://github.com/tclaro/ipen"),

    CreditItem("swiftrex",
               Text(verbatim: "SwiftRex"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.swiftrexDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/SwiftRex/SwiftRex"),

    CreditItem("fp",
               Text(verbatim: "FP"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.fpDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/FP"),

    CreditItem("swiftcalx",
               Text(verbatim: "SwiftCalx"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.swiftcalxDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/SwiftCalx"),

    CreditItem("networktools",
               Text(verbatim: "NetworkTools"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.networktoolsDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/NetworkTools"),

    CreditItem("reactiveconcurrency",
               Text(verbatim: "ReactiveConcurrency"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.reactiveDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/ReactiveConcurrency"),

    CreditItem("hourglass",
               Text(verbatim: "Hourglass"),
               subtitle: Text(verbatim: "© Luiz Rodrigo Martins Barbosa"),
               detail: Text(L.Credits.hourglassDetail),
               license: "Apache 2.0",
               urlString: "https://github.com/luizmb/Hourglass"),

    CreditItem("xmlcoder",
               Text(verbatim: "XMLCoder"),
               subtitle: Text(L.Credits.contributors),
               detail: Text(L.Credits.xmlcoderDetail),
               license: "MIT",
               urlString: "https://github.com/CoreOffice/XMLCoder"),
]
