//
//  DataProcessor.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import Foundation

struct Vector3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    var magnitude: Double { sqrt(x * x + y * y + z * z) }

    func normalized() -> Vector3 {
        let m = magnitude
        return m > 0 ? .init(x: x / m, y: y / m, z: z / m) : .init(x: 0, y: 0, z: 0)
    }

    func dot(_ o: Vector3) -> Double { x * o.x + y * o.y + z * o.z }

    func component(_ axis: Axis) -> Double {
        switch axis {
        case .x: return x
        case .y: return y
        case .z: return z
        }
    }

    static func + (l: Vector3, r: Vector3) -> Vector3 {
        .init(x: l.x + r.x, y: l.y + r.y, z: l.z + r.z)
    }
}

enum Axis: String, CaseIterable, Identifiable {
    case x, y, z
    var id: String { rawValue }
}

struct ProcessedSample: Identifiable, Equatable {
    let id: Int64
    let timestamp: TimeInterval
    let angleAlgo1: Double
    let angleAlgo2: Double
}

final class DataProcessor {
    private let ewmaAlpha: Double
    private let complementaryAlpha: Double
    private let elevationAxis: Axis
    private let gyroAxis: Axis
    private let invertAngle: Bool

    private var prevEwma: Double?
    private var prevAngle2: Double?
    private var prevTimestamp: TimeInterval?

    private var offsetDeg: Double = 0
    private var scale: Double = 1
    private var rawAt0: Double?
    private var rawAt90: Double?

    init(
        ewmaAlpha: Double = 0.2,
        complementaryAlpha: Double = 0.98,
        elevationAxis: Axis = .z,
        gyroAxis: Axis = .z,
        invertAngle: Bool = false
    ) {
        self.ewmaAlpha = min(max(ewmaAlpha, 0), 1)
        self.complementaryAlpha = min(max(complementaryAlpha, 0), 1)
        self.elevationAxis = elevationAxis
        self.gyroAxis = gyroAxis
        self.invertAngle = invertAngle
    }

    func reset() {
        prevEwma = nil
        prevAngle2 = nil
        prevTimestamp = nil
    }

    func resetAll() {
        reset()
        offsetDeg = 0
        scale = 1
        rawAt0 = nil
        rawAt90 = nil
    }

    func calibrate(accel: Vector3, expectedAngleDeg: Double) {
        let raw = rawAngleDeg(from: accel)

        if expectedAngleDeg <= 1 { rawAt0 = raw }
        if abs(expectedAngleDeg - 90) <= 2 { rawAt90 = raw }

        if let r0 = rawAt0 { offsetDeg = r0 }
        else { offsetDeg = raw - expectedAngleDeg }

        if let r0 = rawAt0, let r90 = rawAt90 {
            let d = r90 - r0
            scale = abs(d) > 1e-6 ? 90.0 / d : 1
        } else {
            scale = 1
        }
    }

    func setCalibration(offsetDeg: Double, scale: Double) {
        self.offsetDeg = offsetDeg
        self.scale = scale
    }

    func process(accel: Vector3, gyroRadPerSec: Vector3?, timestamp: TimeInterval) -> ProcessedSample {
        let a = elevationAngleDeg(from: accel)
        let algo1 = ewma(a)
        let algo2 = complementary(accelAngleDeg: a, gyroRadPerSec: gyroRadPerSec, timestamp: timestamp)
        let id = Int64((timestamp * 1000.0).rounded())
        return .init(id: id, timestamp: timestamp, angleAlgo1: algo1, angleAlgo2: algo2)
    }

    private func ewma(_ x: Double) -> Double {
        if let p = prevEwma {
            let y = ewmaAlpha * x + (1 - ewmaAlpha) * p
            prevEwma = y
            return y
        }
        prevEwma = x
        return x
    }

    private func complementary(accelAngleDeg: Double, gyroRadPerSec: Vector3?, timestamp: TimeInterval) -> Double {
        let dt = prevTimestamp == nil ? 0 : max(0, timestamp - (prevTimestamp ?? timestamp))
        prevTimestamp = timestamp

        let prev = prevAngle2 ?? accelAngleDeg

        var gyroAngle = prev
        if let g = gyroRadPerSec, dt > 0 {
            gyroAngle = prev + g.component(gyroAxis) * dt * (180.0 / Double.pi)
        }

        let fused = complementaryAlpha * gyroAngle + (1 - complementaryAlpha) * accelAngleDeg
        let out = clamp(fused, 0, 180)
        prevAngle2 = out
        return out
    }

    private func rawAngleDeg(from accel: Vector3) -> Double {
        let g = accel.normalized()

        let axis: Vector3
        switch elevationAxis {
        case .x: axis = .init(x: 1, y: 0, z: 0)
        case .y: axis = .init(x: 0, y: 1, z: 0)
        case .z: axis = .init(x: 0, y: 0, z: 1)
        }

        var c = axis.dot(g)
        if c.isNaN { c = 0 }
        c = clamp(c, -1, 1)

        var angle = acos(c) * (180.0 / Double.pi)
        if invertAngle { angle = 180 - angle }
        if angle.isNaN { angle = 0 }
        return clamp(angle, 0, 180)
    }

    private func elevationAngleDeg(from accel: Vector3) -> Double {
        let raw = rawAngleDeg(from: accel)
        var corrected = (raw - offsetDeg) * scale
        if corrected.isNaN { corrected = 0 }
        return clamp(corrected, 0, 180)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
