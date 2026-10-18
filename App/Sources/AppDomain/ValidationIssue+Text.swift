import Domain
import Foundation
import Localization
import SwiftUI

public extension CompartmentalModel.ValidationIssue {
    /// What the issue says, in the reader's language. The domain names the issue; the words are
    /// the app's.
    var text: LocalizedStringKey {
        switch self {
        case .noIntakeCompartment: L.Issues.noIntake
        case let .intakeFractionExceedsOne(total): L.Issues.intakeFractionExceedsOne(total.formatted(.number.precision(.significantDigits(1 ... 4))))
        case .noTrackedCompartment: L.Issues.noTracked
        case let .missingHalfLife(_, name): L.Issues.missingHalfLife(name)
        case let .orphanedCompartment(_, name): L.Issues.orphaned(name)
        case let .danglingConnectionEndpoint(id): L.Issues.dangling(id)
        case let .zeroRateConnection(from, to): L.Issues.zeroRate(from, to)
        }
    }
}
