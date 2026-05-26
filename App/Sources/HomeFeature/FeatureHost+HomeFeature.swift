import SwiftRexArchitecture

public extension Module
where Action == HomeFeature.Action,
      State == HomeFeature.State,
      Environment == HomeFeature.Environment,
      Content == HomeFeature.Content {
    static var home: Self { .init(HomeFeature.self) }
}
