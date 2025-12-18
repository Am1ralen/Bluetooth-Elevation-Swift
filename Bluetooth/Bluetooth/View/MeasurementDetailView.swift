//
//  MeasurementDetailView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import SwiftUI
import Charts

struct MeasurementDetailView: View {
    let measurement: Measurement

    private struct ExportFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    @State private var exportFile: ExportFile?

    private struct ChartPoint: Identifiable {
        let id: String
        let t: Double
        let value: Double
        let algorithm: String
    }

    private var points: [ChartPoint] {
        measurement.samples
            .sorted { $0.timeSeconds < $1.timeSeconds }
            .flatMap { s in
                [
                    ChartPoint(id: "a1-\(s.id.uuidString)", t: s.timeSeconds, value: s.algo1Deg, algorithm: "Algorithm 1"),
                    ChartPoint(id: "a2-\(s.id.uuidString)", t: s.timeSeconds, value: s.algo2Deg, algorithm: "Algorithm 2")
                ]
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(measurement.source.title)
                        .font(.title2)

                    Text(measurement.date.formatted(date: .abbreviated, time: .standard))
                        .font(.subheadline)

                    HStack {
                        Text("Duration: \(String(format: "%.0f", measurement.durationSeconds)) s")
                        Spacer()
                        Text("Samples: \(measurement.samples.count)")
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Chart(points) { p in
                    LineMark(
                        x: .value("Time", p.t),
                        y: .value("Elevation", p.value)
                    )
                    .foregroundStyle(by: .value("Algorithm", p.algorithm))
                }
                .chartYScale(domain: 0...180)
                .chartXScale(domain: 0...max(measurement.durationSeconds, 0.1))
                .chartXAxisLabel("Time (s)")
                .chartYAxisLabel("Elevation (deg)")
                .frame(height: 240)

                Button("Export CSV") {
                    if let url = CSVExporter.exportStored(samples: measurement.samples) {
                        exportFile = ExportFile(url: url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(measurement.samples.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
    }
}
