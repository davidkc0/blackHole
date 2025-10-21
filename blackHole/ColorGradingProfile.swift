//
//  ColorGradingProfile.swift
//  blackHole
//
//  Color grading profiles for retro aesthetic
//

import UIKit

enum ColorGradingProfile {
    case bladeRunner    // Orange/teal contrast
    case tron          // Blue/cyan dominated
    case alien         // Green tinted, high contrast
    case terminator    // Red/blue split
    case standard      // Original colors
    
    var adjustments: ColorAdjustments {
        switch self {
        case .bladeRunner:
            return ColorAdjustments(
                highlights: UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0),
                shadows: UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0),
                saturation: 0.6,
                contrast: 1.3,
                warmth: 0.8
            )
        case .tron:
            return ColorAdjustments(
                highlights: UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),
                shadows: UIColor(red: 0.0, green: 0.05, blue: 0.1, alpha: 1.0),
                saturation: 0.8,
                contrast: 1.4,
                warmth: -0.3
            )
        case .alien:
            return ColorAdjustments(
                highlights: UIColor(red: 0.7, green: 1.0, blue: 0.6, alpha: 1.0),
                shadows: UIColor(red: 0.05, green: 0.1, blue: 0.05, alpha: 1.0),
                saturation: 0.5,
                contrast: 1.5,
                warmth: -0.1
            )
        case .terminator:
            return ColorAdjustments(
                highlights: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),
                shadows: UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
                saturation: 0.7,
                contrast: 1.35,
                warmth: 0.2
            )
        case .standard:
            return ColorAdjustments(
                highlights: .white,
                shadows: .black,
                saturation: 1.0,
                contrast: 1.0,
                warmth: 0.0
            )
        }
    }
}

struct ColorAdjustments {
    let highlights: UIColor
    let shadows: UIColor
    let saturation: CGFloat
    let contrast: CGFloat
    let warmth: CGFloat // -1 (cool) to 1 (warm)
}

