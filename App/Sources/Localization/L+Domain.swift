import SwiftUI

public extension L {
    /// A word the domain carries in English (a field's vocabulary, a unit, a backdrop's name),
    /// in the reader's language: the catalog holds it under the same English key.
    static func domain(_ english: String) -> LocalizedStringKey {
        LocalizedStringKey(english)
    }
}

public extension L {
    /// The same word as a string, for a format that takes one (a unit inside "Duration (%@)").
    static func domainString(_ english: String) -> String {
        String(localized: String.LocalizationValue(english))
    }
}
