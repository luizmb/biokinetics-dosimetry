import SwiftRexArchitecture

public extension FeatureHost
where Action == HomeFeature.Action,
      State == HomeFeature.State,
      Environment == HomeFeature.Environment {
    static var home: Self { .init(HomeFeature.self) }
}
