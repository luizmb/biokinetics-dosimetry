import Foundation

/// Errors that can occur during document save/load operations.
public enum PersistenceError: Error, Sendable, LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case fileSystemFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let m):   "Encoding failed: \(m)"
        case .decodingFailed(let m):   "Decoding failed: \(m)"
        case .fileSystemFailed(let m): "File system error: \(m)"
        }
    }
}
