//
//  ExternalMeasurmentView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import SwiftUI
import SwiftData

struct ExternalMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var externalVM: ExternalViewModel

    private struct ExportFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    @State private var exportFile: ExportFile?
    @State private var didSaveThisRun = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Measurement")
                    .font(.title2)

                Text("Source: External")
                    .font(.headline)

                GraphView(samples: externalVM.samples)

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Algorithm 1 (EWMA)")
                            Text(String(format: "%.1f°", externalVM.latestAngleAlgo1))
                                .font(.title)
                        }
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Algorithm 2 (Complementary)")
                            Text(String(format: "%.1f°", externalVM.latestAngleAlgo2))
                                .font(.title)
                        }
                        Spacer()
                    }
                }

                if externalVM.isMeasuring {
                    Button("Stop Measurement") {
                        externalVM.stopMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Measurement") {
                        didSaveThisRun = false
                        externalVM.startMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Export CSV") {
                    if let url = CSVExporter.exportLive(samples: externalVM.samples) {
                        exportFile = ExportFile(url: url)
                    }
                }
                .disabled(externalVM.samples.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Measurement")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert("Polar Error", isPresented: showPolarAlertBinding()) {
            Button("OK") { externalVM.alertMessage = nil }
        } message: {
            Text(externalVM.alertMessage ?? "")
        }
        .onChange(of: externalVM.isMeasuring) { _, newValue in
            if newValue == false {
                saveMeasurementIfNeeded()
            }
        }
    }

    private func showPolarAlertBinding() -> Binding<Bool> {
        Binding(
            get: { externalVM.alertMessage != nil },
            set: { if !$0 { externalVM.alertMessage = nil } }
        )
    }

    private func saveMeasurementIfNeeded() {
        guard !didSaveThisRun else { return }
        guard !externalVM.samples.isEmpty else { return }

        didSaveThisRun = true

        let t0 = externalVM.samples.first!.timestamp

        let swiftDataSamples = externalVM.samples.map {
            MeasurementSample(
                timeSeconds: $0.timestamp - t0,
                algo1Deg: $0.angleAlgo1,
                algo2Deg: $0.angleAlgo2
            )
        }

        let duration = max(0, externalVM.samples.last!.timestamp - t0)

        let measurement = Measurement(
            source: .externalPolar,
            durationSeconds: min(externalVM.maxDurationSeconds, duration),
            samples: swiftDataSamples
        )

        modelContext.insert(measurement)
        try? modelContext.save()
    }
}
