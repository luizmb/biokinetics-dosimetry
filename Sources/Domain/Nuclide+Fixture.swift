#if DEBUG
public extension Nuclide {
    static func fixture(
        id:       String = "n0",
        name:     String = "Test Nuclide",
        halfLife: Double = 0
    ) -> Nuclide {
        Nuclide(id: id, name: name, halfLife: halfLife)
    }
}
#endif
