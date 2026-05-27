import SwiftRexArchitecture

public extension Module
where Action == EditorFeature.Action,
      State == EditorFeature.State,
      Environment == EditorFeature.Environment,
      Content == EditorFeature.Content {
    static var editor: Self { .init(EditorFeature.self) }
}
