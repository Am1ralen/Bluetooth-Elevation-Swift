//
//  ExternalViewModel.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//

import Foundation
import Combine

@MainActor
final class ExternalViewModel: ObservableObject {

    @Published var devices: [PolarSensorManager.PolarDevice] = []
    @Published var isConnected = false
    @Published var connectedDeviceId: String?
    @Published var isMeasuring = false

    @Published var latestAngleAlgo1: Double = 0
    @Published var latestAngleAlgo2: Double = 0
    @Published var samples: [ProcessedSample] = []

    @Published var alertMessage: String?
    @Published var maxDurationSeconds: Double = 30

    private var isBluetoothOn: Bool = true
    
    private var stopTimer: Timer?

    private let manager = PolarSensorManager(
        accUnit: .milliG,
        gyroUnit: .degreesPerSecond
    )

    private let processor = DataProcessor(
        ewmaAlpha: 0.2,
        complementaryAlpha: 0.98,
        elevationAxis: .z,
        gyroAxis: .z,
        invertAngle: true
    )

    init() {
        manager.onDevicesUpdated = { [weak self] list in
            self?.devices = list
        }

        manager.onConnectionStateChanged = { [weak self] connected in
            guard let self else { return }

            self.isConnected = connected

            if connected {
                self.connectedDeviceId = self.manager.currentConnectedDeviceId
            } else {
                self.connectedDeviceId = nil
                self.isMeasuring = false
            }
        }

        manager.onError = { [weak self] msg in
            self?.alertMessage = msg
        }

        manager.onFusedSample = { [weak self] acc, gyro, t in
            guard let self, self.isMeasuring else { return }

            let p = self.processor.process(accel: acc, gyroRadPerSec: gyro, timestamp: t)

            self.latestAngleAlgo1 = p.angleAlgo1
            self.latestAngleAlgo2 = p.angleAlgo2
            self.samples.append(p)
        }

        manager.onBluetoothPowerOn = { [weak self] in
            self?.isBluetoothOn = true
        }

        manager.onBluetoothPowerOff = { [weak self] in
            self?.isBluetoothOn = false
        }
    }

    func requestScan() {
        guard isBluetoothOn else {
            alertMessage = "Bluetooth is turned off. Please enable Bluetooth."
            return
        }

        devices.removeAll()
        manager.startScan()
    }


    func requestConnect(to device: PolarSensorManager.PolarDevice) {
        guard isBluetoothOn else {
            alertMessage = "Bluetooth is turned off. Please enable Bluetooth."
            return
        }

        manager.connect(deviceId: device.id)
    }


    func disconnect() {
        guard let id = connectedDeviceId else { return }
        stopMeasurement()
        manager.disconnect(deviceId: id)
        connectedDeviceId = nil
        isConnected = false
    }

    func startMeasurement() {
        guard !isMeasuring else { return }

        guard isConnected, let id = connectedDeviceId else {
            alertMessage = "Polar is not connected yet."
            return
        }

        samples = []
        latestAngleAlgo1 = 0
        latestAngleAlgo2 = 0
        processor.reset()

        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(
            withTimeInterval: maxDurationSeconds,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopMeasurement()
            }
        }

        isMeasuring = true
        manager.startStreaming(deviceId: id)
    }

    func stopMeasurement() {
        guard isMeasuring else { return }

        stopTimer?.invalidate()
        stopTimer = nil

        manager.stopStreaming()
        isMeasuring = false
    }
}
