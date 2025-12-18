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
            VStack {

                // Texten längst upp
                Text("Welcome")
                    .font(.largeTitle)
                    .padding(.top, 60)
                
                Text("Measure your arm elevation using different sensors")
                    .font(.subheadline)
                    

                Spacer() // <-- trycker ner resten

                VStack(spacing: 15) {

                    NavigationLink("Internal Sensor Measurement") {
                        InternalMeasurementView()
                    }
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .buttonStyle(.bordered)

                    NavigationLink("External Sensor Measurement") {
                        ExternalMeasurementView(externalVM: externalVM)
                    }
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .buttonStyle(.bordered)

                    NavigationLink("Connect External Sensor") {
                        PolarConnectView(externalVM: externalVM)
                    }
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .buttonStyle(.bordered)

                    if externalVM.isConnected {
                        Text("External sensor connected")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    NavigationLink("History") {
                        HistoryView()
                    }
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .buttonStyle(.bordered)
                }

                Spacer() // <-- balanserar layouten snyggt
            }
            .padding()
        }
    }
}
