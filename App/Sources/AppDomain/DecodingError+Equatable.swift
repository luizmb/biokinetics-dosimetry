import Foundation

/// Retroactive `Equatable` conformance for `DecodingError`.
///
/// `DecodingError` is used as the failure type in `Loading<[ModelDocument], DecodingError>`.
/// Equatability is required for `Loading` to conform to `Equatable`.
/// The implementation is intentionally coarse — two errors are equal when their
/// human-readable descriptions match. Precise structural equality would require
/// exhaustive switching over every associated value, with no practical benefit here.
extension DecodingError: @retroactive Equatable {
    public static func == (lhs: DecodingError, rhs: DecodingError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
