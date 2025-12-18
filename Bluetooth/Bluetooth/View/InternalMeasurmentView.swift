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
        // Byter från ScrollView till att "pinna" bottenknapparna.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Measurement")
                        .font(.title2)

                    Text("Source: Internal")
                        .font(.headline)

                    GraphView(samples: internalVM.samples)
                        .padding(.top, 4)

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

                    // Lite luft så att innehållet inte hamnar bakom bottenknapparna
                    Spacer(minLength: 90)
                }
                .padding()
            }

            // ---- Bottom actions (alltid längst ner) ----
            VStack(spacing: 12) {
                if internalVM.isMeasuring {
                    Button("Stop Measurement") {
                        internalVM.stopMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Start Measurement") {
                        didSaveThisRun = false
                        internalVM.startMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }

                Button("Export CSV") {
                    if let url = CSVExporter.exportLive(samples: internalVM.samples) {
                        exportFile = ExportFile(url: url)
                    }
                }
                .disabled(internalVM.samples.isEmpty)
                .buttonStyle(.bordered)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
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
