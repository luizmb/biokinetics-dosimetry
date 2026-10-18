import Foundation
import Localization

/// Errors that can occur during document save/load operations.
public enum PersistenceError: Error, Sendable, LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case fileSystemFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let m):   String(localized: L.Resource.Persistence.encodingFailed(m))
        case .decodingFailed(let m):   String(localized: L.Resource.Persistence.decodingFailed(m))
        case .fileSystemFailed(let m): String(localized: L.Resource.Persistence.fileSystemFailed(m))
        }
    }
}
