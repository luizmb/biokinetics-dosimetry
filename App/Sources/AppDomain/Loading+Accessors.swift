import DataStructure

// FP's `Loading` exposes only cases; these restore the value accessors the app relies on.
public extension Loading {
    var loaded: Success? { if case let .loaded(value) = self { value } else { nil } }
    var failed: (Failure, previous: Success?)? { if case let .failed(error, previous) = self { (error, previous) } else { nil } }
}
