//
//  PolarConnectView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import SwiftUI

struct PolarConnectView: View {

    @ObservedObject var externalVM: ExternalViewModel

    var body: some View {
        VStack(spacing: 16) {

            Text("Connect Sensor")
                .font(.title2)

            Button("Scan for devices") {
                externalVM.requestScan()
            }
            .buttonStyle(.borderedProminent)

            List {
                ForEach(externalVM.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if externalVM.isConnected && externalVM.connectedDeviceId == device.id {
                            Text("Connected")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Button("Connect") {
                                externalVM.requestConnect(to: device)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if externalVM.isConnected {
                Text("Connected to sensor")
                    .foregroundColor(.green)

                Button("Disconnect") {
                    externalVM.disconnect()
                }
                .font(.title3)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .buttonStyle(.bordered)

            } else {
                Text("Not connected")
                    .foregroundColor(.secondary)
            }
        }
        .alert("Polar Error", isPresented: showAlertBinding()) {
            Button("OK") { externalVM.alertMessage = nil }
        } message: {
            Text(externalVM.alertMessage ?? "")
        }
    }

    private func showAlertBinding() -> Binding<Bool> {
        Binding(
            get: { externalVM.alertMessage != nil },
            set: { if !$0 { externalVM.alertMessage = nil } }
        )
    }
}
