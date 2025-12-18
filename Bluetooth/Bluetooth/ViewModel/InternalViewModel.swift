//
//  InternalViewModel.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import Foundation
import CoreMotion
import Combine

@MainActor
final class InternalViewModel: ObservableObject {

    @Published var isMeasuring = false
    @Published var latestAngleAlgo1: Double = 0
    @Published var latestAngleAlgo2: Double = 0
    @Published var samples: [ProcessedSample] = []
    @Published var maxDurationSeconds: Double = 30

    private let motionManager = CMMotionManager()
    private let processor = DataProcessor(
        ewmaAlpha: 0.2,
        complementaryAlpha: 0.98,
        elevationAxis: .z,
        gyroAxis: .z,
        invertAngle: true
    )

    private var stopTimer: Timer?

    func startMeasurement() {
        guard !isMeasuring else { return }
        guard motionManager.isDeviceMotionAvailable else { return }

        samples = []
        latestAngleAlgo1 = 0
        latestAngleAlgo2 = 0
        processor.reset()

        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: maxDurationSeconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.stopMeasurement() }
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        isMeasuring = true

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion, self.isMeasuring else { return }

            let accel = Vector3(
                x: motion.gravity.x + motion.userAcceleration.x,
                y: motion.gravity.y + motion.userAcceleration.y,
                z: motion.gravity.z + motion.userAcceleration.z
            )

            let gyro = Vector3(
                x: motion.rotationRate.x,
                y: motion.rotationRate.y,
                z: motion.rotationRate.z
            )

            let timestamp = Date().timeIntervalSince1970
            let p = self.processor.process(accel: accel, gyroRadPerSec: gyro, timestamp: timestamp)

            self.latestAngleAlgo1 = p.angleAlgo1
            self.latestAngleAlgo2 = p.angleAlgo2
            self.samples.append(p)
        }
    }

    func stopMeasurement() {
        guard isMeasuring else { return }

        stopTimer?.invalidate()
        stopTimer = nil

        motionManager.stopDeviceMotionUpdates()
        isMeasuring = false
    }
}
