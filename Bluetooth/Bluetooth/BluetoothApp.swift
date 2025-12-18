//
//  BluetoothApp.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//

import SwiftUI
import SwiftData

@main
struct BluetoothApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Measurement.self, MeasurementSample.self])
    }
}
