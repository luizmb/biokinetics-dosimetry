//
//  Compartiment.swift
//  MultiCompartmentModel
//
//  Created by Luiz Rodrigo Martins Barbosa on 11.07.17.
//  Copyright © 2017 Luiz Rodrigo Martins Barbosa. All rights reserved.
//

import Foundation

class Compartment: Equatable {
    init(name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double) {
        self.name = name
        self.follow = follow
        self.intake = intake
        self.dispose = dispose
        self.fraction = fraction
    }

    var name: String
    var follow: Bool
    var intake: Bool
    var dispose: Bool
    var fraction: Double

    let connections: [CompartmentConnection] = []

    static func ==(lhs: Compartment, rhs: Compartment) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Array where Element == Compartment {
    func createMatrix() -> [[Double]] {
        let skip = 1
        let n = self.count + skip
        var R: [[Double]] = Array<Array<Double>>(repeating: Array<Double>(repeating: 0.0, count: n), count: n)

        self.enumerated().forEach { i, compartment in
            guard compartment.intake else { return }
            R[i + skip][i + skip] = compartment.fraction
        }

        self.flatMap { $0.connections }
            .flatMap { (self.index(of: $0.transmitter)!, self.index(of: $0.receiver)!, $0.rate) }
            .forEach { (i, j, rate) in R[i + skip][j + skip] = rate }

        return R
    }

    func createMatrixOtherMethods() -> [[Double]] {
        let skip = 0
        let n = self.count + skip
        var R: [[Double]] = Array<Array<Double>>(repeating: Array<Double>(repeating: 0.0, count: n), count: n)

        self.forEach { compartment in
            compartment.connections.forEach { connection in
                let l = self.index(of: compartment)!

                if connection.transmitter == compartment {
                    R[l][l] += connection.rate
                }

                if connection.receiver == compartment {
                    let c = self.index(of: connection.transmitter)!
                    R[l][c] = connection.rate
                }
            }
        }

        for i in 0 ..< R.count {
            R[i][i] *= -1
        }

        return R
    }
}
