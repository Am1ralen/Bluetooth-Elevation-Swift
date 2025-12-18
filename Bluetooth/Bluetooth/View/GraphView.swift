//
//  GraphView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//

import SwiftUI
import Charts

struct GraphView: View {
    let samples: [ProcessedSample]

    private let duration: Double = 30.0
    private let maxPointsPerAlgo: Int = 1500

    private struct ChartPoint: Identifiable {
        let id: String
        let t: Double
        let value: Double
        let algorithm: String
    }

    private var points: [ChartPoint] {
        guard !samples.isEmpty else { return [] }

        let t0 = samples.first!.timestamp

        let clipped = samples.compactMap { s -> (t: Double, a1: Double, a2: Double)? in
            let t = s.timestamp - t0
            guard t >= 0 else { return nil }
            guard t <= duration else { return nil }
            return (t: t, a1: s.angleAlgo1, a2: s.angleAlgo2)
        }

        let downsampled: [(t: Double, a1: Double, a2: Double)]
        if clipped.count > maxPointsPerAlgo {
            let strideN = max(1, clipped.count / maxPointsPerAlgo)
            downsampled = clipped.enumerated().compactMap { (i, v) in
                (i % strideN == 0) ? v : nil
            }
        } else {
            downsampled = clipped
        }

        return downsampled.enumerated().flatMap { (i, s) in
            [
                ChartPoint(id: "a1-\(i)", t: s.t, value: s.a1, algorithm: "Algorithm 1"),
                ChartPoint(id: "a2-\(i)", t: s.t, value: s.a2, algorithm: "Algorithm 2")
            ]
        }
    }

    var body: some View {
        Chart(points) { p in
            LineMark(
                x: .value("Time", p.t),
                y: .value("Elevation", p.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(by: .value("Algorithm", p.algorithm))
        }
        .chartYScale(domain: 0...180)
        .chartXScale(domain: 0...duration)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0.0, through: duration, by: 5.0))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text("\(Int(t))s")
                    }
                }
            }
        }
        .chartXAxisLabel("Time (s)")
        .chartYAxisLabel("Elevation (deg)")
        .frame(maxWidth: .infinity)   // <-- gör den horisontellt större
        .frame(height: 300)           // <-- lite högre också (justera fritt)
        .transaction { $0.animation = nil }
    }
}
