//
//  HomeView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import SwiftUI

struct HomeView: View {

    @StateObject private var externalVM = ExternalViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Text("Arm Elevation")
                    .font(.largeTitle)

                NavigationLink("Internal Measurement") {
                    InternalMeasurementView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("External Measurement") {
                    ExternalMeasurementView(externalVM: externalVM)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!externalVM.isConnected)

                NavigationLink("Connect External Sensor") {
                    PolarConnectView(externalVM: externalVM)
                }
                .buttonStyle(.bordered)

                if externalVM.isConnected {
                    Text("External sensor connected")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                NavigationLink("History") {
                    HistoryView()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
