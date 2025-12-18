//
//  CSVExporter.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//
import Foundation

struct CSVExporter {

    static func exportLive(samples: [ProcessedSample]) -> URL? {
        guard !samples.isEmpty else { return nil }

        let header = "time_seconds,algorithm1_deg,algorithm2_deg\n"
        let t0 = samples.first!.timestamp

        let rows = samples
            .map {
                String(
                    format: "%.3f,%.2f,%.2f",
                    $0.timestamp - t0,
                    $0.angleAlgo1,
                    $0.angleAlgo2
                )
            }
            .joined(separator: "\n")

        return writeCSV(
            header: header,
            rows: rows,
            filenamePrefix: "arm_elevation_live"
        )
    }

    static func exportStored(samples: [MeasurementSample]) -> URL? {
        guard !samples.isEmpty else { return nil }

        let header = "time_seconds,algorithm1_deg,algorithm2_deg\n"

        let rows = samples
            .sorted { $0.timeSeconds < $1.timeSeconds }
            .map {
                String(
                    format: "%.3f,%.2f,%.2f",
                    $0.timeSeconds,
                    $0.algo1Deg,
                    $0.algo2Deg
                )
            }
            .joined(separator: "\n")

        return writeCSV(
            header: header,
            rows: rows,
            filenamePrefix: "arm_elevation_saved"
        )
    }

    private static func writeCSV(
        header: String,
        rows: String,
        filenamePrefix: String
    ) -> URL? {

        let csvString = header + rows
        let filename = "\(filenamePrefix)_\(Int(Date().timeIntervalSince1970)).csv"

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let exportsDir = docs.appendingPathComponent("Exports", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: exportsDir,
                withIntermediateDirectories: true
            )
            let url = exportsDir.appendingPathComponent(filename)
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
