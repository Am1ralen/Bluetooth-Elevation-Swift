//
//  PolarSensorManager.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import Foundation
import CoreBluetooth
import PolarBleSdk
import RxSwift

final class PolarSensorManager: NSObject {

    struct PolarDevice: Identifiable, Equatable {
        let id: String
        let name: String
        let rssi: Int
    }

    var onDevicesUpdated: (([PolarDevice]) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onBluetoothPowerOn: (() -> Void)?
    var onBluetoothPowerOff: (() -> Void)?

    var onFusedSample: ((Vector3, Vector3?, TimeInterval) -> Void)?
    var onAccSample: ((Vector3, TimeInterval) -> Void)?
    var onGyroSample: ((Vector3, TimeInterval) -> Void)?

    enum AccUnit { case milliG, g, metersPerSecondSquared }
    enum GyroUnit { case degreesPerSecond, radiansPerSecond }

    private let accUnit: AccUnit
    private let gyroUnit: GyroUnit
    private let fusionWindow: TimeInterval = 0.05

    private var api: PolarBleApi
    private var devices: [PolarDevice] = []
    private(set) var currentConnectedDeviceId: String?

    private var scanDisposable: Disposable?
    private var accSettingsDisposable: Disposable?
    private var gyroSettingsDisposable: Disposable?
    private var accStreamDisposable: Disposable?
    private var gyroStreamDisposable: Disposable?

    private var lastAcc: Vector3?
    private var lastAccTs: TimeInterval?
    private var lastGyro: Vector3?
    private var lastGyroTs: TimeInterval?

    init(accUnit: AccUnit = .milliG, gyroUnit: GyroUnit = .degreesPerSecond) {
        self.accUnit = accUnit
        self.gyroUnit = gyroUnit

        let features: Set<PolarBleSdkFeature> = [
            .feature_polar_online_streaming,
            .feature_battery_info
        ]

        self.api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: features)
        super.init()

        api.observer = self
        api.deviceInfoObserver = self
        api.powerStateObserver = self
    }

    func startScan() {
        stopScan()
        devices = []
        onDevicesUpdated?(devices)

        scanDisposable = api.searchForDevice()
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] d in
                    guard let self else { return }
                    let name = d.name
                    let id = d.deviceId
                    let rssi = d.rssi

                    let lower = name.lowercased()
                    let isPolarName = lower.contains("polar") || lower.contains("verity")
                    if !isPolarName { return }

                    let item = PolarDevice(id: id, name: name, rssi: rssi)

                    if let i = self.devices.firstIndex(where: { $0.id == id }) {
                        self.devices[i] = item
                    } else {
                        self.devices.append(item)
                    }

                    self.onDevicesUpdated?(self.devices.sorted { $0.rssi > $1.rssi })
                },
                onError: { [weak self] e in
                    self?.onError?("Scan error: \(e.localizedDescription)")
                }
            )
    }

    func stopScan() {
        scanDisposable?.dispose()
        scanDisposable = nil
    }

    func connect(deviceId: String) {
        stopScan()
        do { try api.connectToDevice(deviceId) }
        catch { onError?("Connect failed: \(error.localizedDescription)") }
    }

    func disconnect(deviceId: String) {
        stopStreaming()
        do { try api.disconnectFromDevice(deviceId) }
        catch { onError?("Disconnect failed: \(error.localizedDescription)") }
    }

    func startStreaming(deviceId: String) {
        stopStreaming()
        lastAcc = nil; lastAccTs = nil
        lastGyro = nil; lastGyroTs = nil

        startAcc(deviceId: deviceId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.startGyro(deviceId: deviceId)
        }
    }

    func stopStreaming() {
        accSettingsDisposable?.dispose(); accSettingsDisposable = nil
        gyroSettingsDisposable?.dispose(); gyroSettingsDisposable = nil
        accStreamDisposable?.dispose(); accStreamDisposable = nil
        gyroStreamDisposable?.dispose(); gyroStreamDisposable = nil
    }

    private func startAcc(deviceId: String) {
        accSettingsDisposable?.dispose()
        accStreamDisposable?.dispose()
        accSettingsDisposable = nil
        accStreamDisposable = nil

        accSettingsDisposable = api.requestStreamSettings(deviceId, feature: .acc)
            .subscribe(
                onSuccess: { [weak self] settings in
                    guard let self else { return }

                    let best = settings.maxSettings()

                    self.accStreamDisposable = self.api.startAccStreaming(deviceId, settings: best)
                        .observe(on: MainScheduler.instance)
                        .subscribe(
                            onNext: { [weak self] arr in
                                guard let self else { return }
                                for s in arr {
                                    let v = self.convertAcc(x: Double(s.x), y: Double(s.y), z: Double(s.z))
                                    let t = TimeInterval(s.timeStamp) / 1_000_000_000.0
                                    self.lastAcc = v
                                    self.lastAccTs = t
                                    self.onAccSample?(v, t)
                                    self.emitFused(accTs: t)
                                }
                            },
                            onError: { [weak self] e in
                                self?.onError?("ACC stream error: \(e.localizedDescription)")
                            }
                        )
                },
                onFailure: { [weak self] e in
                    self?.onError?("ACC settings error: \(e.localizedDescription)")
                }
            )
    }

    private func startGyro(deviceId: String) {
        gyroSettingsDisposable?.dispose()
        gyroStreamDisposable?.dispose()
        gyroSettingsDisposable = nil
        gyroStreamDisposable = nil

        gyroSettingsDisposable = api.requestStreamSettings(deviceId, feature: .gyro)
            .subscribe(
                onSuccess: { [weak self] settings in
                    guard let self else { return }

                    let best = settings.maxSettings()

                    self.gyroStreamDisposable = self.api.startGyroStreaming(deviceId, settings: best)
                        .observe(on: MainScheduler.instance)
                        .subscribe(
                            onNext: { [weak self] arr in
                                guard let self else { return }
                                for s in arr {
                                    let v = self.convertGyro(x: Double(s.x), y: Double(s.y), z: Double(s.z))
                                    let t = TimeInterval(s.timeStamp) / 1_000_000_000.0
                                    self.lastGyro = v
                                    self.lastGyroTs = t
                                    self.onGyroSample?(v, t)
                                }
                            },
                            onError: { [weak self] e in
                                self?.onError?("GYRO stream error: \(e.localizedDescription)")
                            }
                        )
                },
                onFailure: { [weak self] _ in
                    self?.onError?("Gyroscope not available right now. Measurement will continue with ACC only.")
                }
            )
    }

    private func emitFused(accTs: TimeInterval) {
        guard let acc = lastAcc else { return }

        var gyro: Vector3?
        if let gt = lastGyroTs, let g = lastGyro, abs(accTs - gt) <= fusionWindow {
            gyro = g
        }

        onFusedSample?(acc, gyro, accTs)
    }

    private func convertAcc(x: Double, y: Double, z: Double) -> Vector3 {
        switch accUnit {
        case .milliG:
            return .init(x: (x / 1000.0) * 9.81, y: (y / 1000.0) * 9.81, z: (z / 1000.0) * 9.81)
        case .g:
            return .init(x: x * 9.81, y: y * 9.81, z: z * 9.81)
        case .metersPerSecondSquared:
            return .init(x: x, y: y, z: z)
        }
    }

    private func convertGyro(x: Double, y: Double, z: Double) -> Vector3 {
        switch gyroUnit {
        case .degreesPerSecond:
            let k = Double.pi / 180.0
            return .init(x: x * k, y: y * k, z: z * k)
        case .radiansPerSecond:
            return .init(x: x, y: y, z: z)
        }
    }
}

extension PolarSensorManager: PolarBleApiObserver {
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        onConnectionStateChanged?(false)
    }

    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        currentConnectedDeviceId = polarDeviceInfo.deviceId
        onConnectionStateChanged?(true)
    }

    func deviceDisconnected(_ identifier: PolarDeviceInfo, pairingError: Bool) {
        currentConnectedDeviceId = nil
        onConnectionStateChanged?(false)
    }
}

extension PolarSensorManager: PolarBleApiDeviceInfoObserver {
    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {}
    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: BleBasClient.ChargeState) {}
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {}
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {}
}

extension PolarSensorManager: PolarBleApiPowerStateObserver {
    func blePowerOn() {
        onBluetoothPowerOn?()
    }
    func blePowerOff() {
        onBluetoothPowerOff?()
    }
}
