import EditorFeature
import SwiftRexArchitecture

public extension FeatureHost
where Action == EditorFeature.Action,
      State == EditorFeature.State,
      Environment == EditorFeature.Environment {
    static var editor: Self { .init(EditorFeature.self) }
}
