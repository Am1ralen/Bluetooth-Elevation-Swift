//
//  SensorSource.swift
//  Bluetooth
//
//  Created by Amir Alshammaa on 2025-12-17.
//

import Foundation

enum SensorSource: String, Codable, CaseIterable, Identifiable {
    case internalPhone
    case externalPolar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .internalPhone: return "Internal"
        case .externalPolar: return "External"
        }
    }
}
