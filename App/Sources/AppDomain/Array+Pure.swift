/// Wraps a single element in an array — the `pure` / `return` of the List applicative.
///
/// Equivalent to `[element]`. Named `pure` after the Applicative Functor operation.
/// This will eventually move to the FP package.
public extension Array {
    static func pure(_ element: Element) -> Self { [element] }
}
