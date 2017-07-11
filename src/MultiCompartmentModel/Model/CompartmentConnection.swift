//
//  ComparmentConnection.swift
//  MultiCompartmentModel
//
//  Created by Luiz Rodrigo Martins Barbosa on 11.07.17.
//  Copyright © 2017 Luiz Rodrigo Martins Barbosa. All rights reserved.
//

import Foundation

class CompartmentConnection: Equatable {
    init(transmitter: Compartment, receiver: Compartment,  rate: Double) {
        self.transmitter = transmitter
        self.receiver = receiver
        self.rate = rate
    }

    var transmitter: Compartment
    var receiver: Compartment
    var rate: Double

    static func ==(lhs: CompartmentConnection, rhs: CompartmentConnection) -> Bool {
        return lhs.transmitter == rhs.transmitter && lhs.receiver == rhs.receiver
    }
}
