import Domain
import Foundation
import Localization
import SwiftUI

public extension CompartmentalModel.ValidationIssue {
    /// What the issue says, in the reader's language, a number in it written by `number` (the
    /// world's, applied where the view state is made). The domain names the issue; the words are
    /// the app's.
    func text(_ number: (Double) -> String) -> LocalizedStringResource {
        switch self {
        case .noIntakeCompartment: L.Resource.Issues.noIntake
        case let .intakeFractionExceedsOne(total): L.Resource.Issues.intakeFractionExceedsOne(number(total))
        case .noTrackedCompartment: L.Resource.Issues.noTracked
        case let .missingHalfLife(_, name): L.Resource.Issues.missingHalfLife(name)
        case let .orphanedCompartment(_, name): L.Resource.Issues.orphaned(name)
        case let .danglingConnectionEndpoint(id): L.Resource.Issues.dangling(id)
        case let .zeroRateConnection(from, to): L.Resource.Issues.zeroRate(from, to)
        }
    }
}
