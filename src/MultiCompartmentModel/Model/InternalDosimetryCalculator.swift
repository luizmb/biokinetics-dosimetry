//
//  InternalDosimetryCalculator.swift
//  MultiCompartmentModel
//
//  Created by Luiz Rodrigo Martins Barbosa on 11.07.17.
//  Copyright © 2017 Luiz Rodrigo Martins Barbosa. All rights reserved.
//

import Foundation

struct InternalDosimetryCalculator {
    init(step: Int, halfLife: Double, final: Int) {
        self.step = step
        self.halfLife = halfLife
        self.final = final
        self.stepCount = Int(Double(final) / Double(step))
        if halfLife > 0 {
            self.lambdaR = log(2) / halfLife
        } else {
            self.lambdaR = 0.0
        }
    }

    let startTime = Date()
    var step: Int
    var halfLife: Double
    var final: Int
    var stepCount: Int
    var lambdaR: Double

    func calculate(R: [[Double]]) -> [[Double]] {
        var stepsOutput: [[Double]] = []

        var output = DifferentialEquationCalculator(size: R.count)
        var currentTime = 0

        for _ in 0 ... stepCount + 1 {
            let input = InputMatrix(R: R, lambdaR: self.lambdaR, time: stepCount)
            output.calculateStep(from: input)
            stepsOutput.append(output.xt)
            currentTime += step
        }

        return stepsOutput
    }
}

struct InputMatrix {
    var n: Int {
        return R.count
    }

    var R: [[Double]]
    var lambdaR: Double
    var time: Int
    let tError: Double = 1E-10
}

struct DifferentialEquationCalculator {
    var sum: [[Double]]

    var a: [[Double]]
    var term: [[Double]]
    var b: [[Double]]

    var xt: [Double]
    var xo: [Double]
    var u: [Double]

    var q: [[Double]]
    var qi: [[Double]]
    var max: Double

    init(size n: Int) {
        sum = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        a = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        term = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        b = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        xt = Array(repeating: 0.0, count: n)
        xo = Array(repeating: 0.0, count: n)
        u = Array(repeating: 0.0, count: n)

        q = Array(repeating: Array(repeating: 0.0, count: n * 2), count: n * 2)
        qi = Array(repeating: Array(repeating: 0.0, count: n * 2), count: n * 2)
        max = 0.0
    }

    mutating func calculateStep(from input: InputMatrix) {
        for i in 1 ..< input.n {
            for j in 1 ..< input.n {
                sum[i][j] = 0
                a[i][j] = input.R[j][i]
            }
        }

        for i in 1 ..< input.n
        {
            a[i][i] = -input.lambdaR
            for k in 1 ..< input.n {
                if k != i {
                    a[i][i] -= input.R[i][k]
                }
            }
        }

        for i in 1 ..< input.n {
            xo[i] = input.R[i][i]
            sum[i][i] = 1
            term[i][i] = 1
        }

        for i in 1 ..< input.n {
            for j in 1 ..< input.n {
                q[i][j] = a[i][j]
                a[i][j] *= Double(input.time)
            }
        }

        for i in 1 ..< input.n {
            if a[i][i] < max {
                max = a[i][i]
            }
        }

        let iz: Int = {
            for iz in 0 ... 1000 {
                if -max / exp(log(2) * Double(iz)) < 0.2 {
                    return iz
                }
            }
            return 1000
        }()

        for i in 1 ..< input.n {
            for j in 1 ..< input.n {
                a[i][j] /= (exp(log(2) * Double(iz)))
            }
        }

        for ir in 1 ... 10000 {
            for j in 1 ..< input.n {
                for i in 1 ..< input.n {
                    b[i][j] = 0
                    for k in 1 ..< input.n {
                        b[i][j] += term[i][k] * a[k][j]
                    }
                }
            }

            for i in 1 ..< input.n {
                for j in 1 ..< input.n {
                    term[i][j] = b[i][j] / Double(ir)
                    sum[i][j] += term[i][j]
                }
            }

            if !{
                for i in 1 ..< input.n {
                    for j in 1 ..< input.n {
                        if sum[i][j] != 0, term[i][j] / sum[i][j] > input.tError {
                            return true
                        }
                    }
                }
                return false
                }() {
                break
            }
        }

        for _ in 1 ..< iz + 1 {
            for i in 1 ..< input.n {
                for j in 1 ..< input.n {
                    a[i][j] = 0
                    for k in 1 ..< input.n {
                        a[i][j] += sum[i][k] * sum[k][j]
                    }
                }
            }

            for i in 1 ..< input.n {
                for j in 1 ..< input.n {
                    sum[i][j] = a[i][j]
                }
            }
        }

        if input.lambdaR != 0 {
            inversion(size: input.n)
        }

        for i in 1 ..< input.n {
            xt[i] = 0
            for k in 1 ..< input.n {
                xt[i] += sum[i][k] * xo[k]
            }
        }

        if input.lambdaR != 0 {
            for i in 1 ..< input.n {
                sum[i][i] -= 1
            }

            for i in 1 ..< input.n {
                for j in 1 ..< input.n {
                    b[i][j] = 0
                    for id in 1 ..< input.n {
                        b[i][j] += qi[i][id] * sum[id][j]
                    }
                }
            }

            for i in 1 ..< input.n {
                u[i] = 0
                for j in 1 ..< input.n {
                    u[i] += b[i][j] * xo[j]
                }
                u[i] *= input.lambdaR
            }
        }
    }

    mutating func inversion(size n: Int) {
        for i in 1 ..< n {
            for k in n ..< 2 * n {
                q[i][k] = 0
            }
            q[i][i + (n - 1)] = 1
        }

        for i in 1 ..< n {
            for j in 1 ..< n {
                qi[i][j] = q[i][j + i] / (q[i][i])
                qi[i][j] = qi[i][j]
            }

            for k in 1 ..< n {
                guard i != k else { continue }

                for l in 1 ..< n {
                    qi[k][l] = q[k][l + i] - q[k][i] * qi[i][l]
                }
            }

            for k in 1 ..< n {
                for l in 1 ..< n {
                    q[k][l + i] = qi[k][l]
                }
            }
        }
    }
}
