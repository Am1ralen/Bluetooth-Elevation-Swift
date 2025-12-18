//
//  InternalMeasurmentView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-18.
//
import SwiftUI
import SwiftData

struct InternalMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var internalVM = InternalViewModel()

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

                Text("Source: Internal")
                    .font(.headline)

                GraphView(samples: internalVM.samples)

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Algorithm 1 (EWMA)")
                            Text(String(format: "%.1f°", internalVM.latestAngleAlgo1))
                                .font(.title)
                        }
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Algorithm 2 (Complementary)")
                            Text(String(format: "%.1f°", internalVM.latestAngleAlgo2))
                                .font(.title)
                        }
                        Spacer()
                    }
                }

                if internalVM.isMeasuring {
                    Button("Stop Measurement") {
                        internalVM.stopMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Measurement") {
                        didSaveThisRun = false
                        internalVM.startMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Export CSV") {
                    if let url = CSVExporter.exportLive(samples: internalVM.samples) {
                        exportFile = ExportFile(url: url)
                    }
                }
                .disabled(internalVM.samples.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Measurement")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .onChange(of: internalVM.isMeasuring) { _, newValue in
            if newValue == false {
                saveMeasurementIfNeeded()
            }
        }
    }

    private func saveMeasurementIfNeeded() {
        guard !didSaveThisRun else { return }
        guard !internalVM.samples.isEmpty else { return }

        didSaveThisRun = true

        let t0 = internalVM.samples.first!.timestamp

        let swiftDataSamples = internalVM.samples.map {
            MeasurementSample(
                timeSeconds: $0.timestamp - t0,
                algo1Deg: $0.angleAlgo1,
                algo2Deg: $0.angleAlgo2
            )
        }

        let duration = max(0, internalVM.samples.last!.timestamp - t0)

        let measurement = Measurement(
            source: .internalPhone,
            durationSeconds: min(internalVM.maxDurationSeconds, duration),
            samples: swiftDataSamples
        )

        modelContext.insert(measurement)
        try? modelContext.save()
    }
}
