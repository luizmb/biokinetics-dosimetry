import Domain

public extension ModelDocument {
    /// The same document with the texts a reader sees passed through `translate`: its name and
    /// description, and its nuclides' and compartments' names. A sample is seeded in the reader's
    /// language this way; a text `translate` doesn't know comes back as it was.
    func localized(by translate: (String) -> String) -> ModelDocument {
        ModelDocument(
            id: id,
            name: translate(name),
            description: translate(description),
            field: field,
            model: model.localized(by: translate),
            variants: variants.mapValues { $0.localized(by: translate) },
            visuals: visuals,
            backdrop: backdrop
        )
    }
}

extension CompartmentalModel {
    func localized(by translate: (String) -> String) -> CompartmentalModel {
        with(
            nuclides: nuclides.map { $0.with(name: translate($0.name)) },
            compartments: compartments.map { $0.with(name: translateLed($0.name, translate)) }
        )
    }
}

/// A chain's compartments are named after their nuclide, "U238 Plasma": the nuclide stays and the
/// rest is translated, when the whole name isn't a text `translate` knows.
func translateLed(_ name: String, _ translate: (String) -> String) -> String {
    switch (translate(name), name.split(separator: " ", maxSplits: 1).map(String.init)) {
    case let (whole, parts) where whole == name && parts.count == 2 && parts[0].contains(where: \.isNumber):
        parts[0] + " " + translate(parts[1])
    case let (whole, _):
        whole
    }
}
