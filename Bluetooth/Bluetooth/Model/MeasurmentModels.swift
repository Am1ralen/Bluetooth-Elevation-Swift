//
//  MeasurmentModels.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import Foundation
import SwiftData

@Model
final class Measurement {
    @Attribute(.unique) var id: UUID
    var date: Date
    var source: SensorSource
    var durationSeconds: Double
    @Relationship(deleteRule: .cascade) var samples: [MeasurementSample]

    init(
        date: Date = Date(),
        source: SensorSource,
        durationSeconds: Double,
        samples: [MeasurementSample] = []
    ) {
        self.id = UUID()
        self.date = date
        self.source = source
        self.durationSeconds = durationSeconds
        self.samples = samples
    }
}

@Model
final class MeasurementSample {
    @Attribute(.unique) var id: UUID
    var timeSeconds: Double
    var algo1Deg: Double
    var algo2Deg: Double

    init(timeSeconds: Double, algo1Deg: Double, algo2Deg: Double) {
        self.id = UUID()
        self.timeSeconds = timeSeconds
        self.algo1Deg = algo1Deg
        self.algo2Deg = algo2Deg
    }
}
