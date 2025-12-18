//
//  HistoryView.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Measurement.date, order: .reverse) private var measurements: [Measurement]

    var body: some View {
        List {
            ForEach(measurements) { m in
                NavigationLink {
                    MeasurementDetailView(measurement: m)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(m.source.title)
                            .font(.headline)

                        Text(m.date.formatted(date: .abbreviated, time: .standard))
                            .font(.subheadline)

                        Text("Samples: \(m.samples.count)")
                            .font(.caption)
                    }
                }
            }
            .onDelete(perform: deleteMeasurements)
        }
        .navigationTitle("History")
    }

    private func deleteMeasurements(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(measurements[i])
        }
        try? modelContext.save()
    }
}
