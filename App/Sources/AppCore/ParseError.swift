import Foundation

/// A lightweight error type wrapping a human-readable parse failure message.
///
/// Used wherever the parsing pipeline needs to return a typed `Result` failure
/// that satisfies `Swift.Error` while still carrying the localised description
/// from the underlying decoder.
public struct ParseError: Error, Sendable, Equatable, LocalizedError {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}
