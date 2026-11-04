import XCTest
import SwiftUI
@testable import FitBOSSApp

final class BOSSPresentationTests: XCTestCase {
    func testAppearanceUnknownFollowsSystem() {
        XCTAssertNil(BOSSAppearance.resolve("future-value").colorScheme)
        XCTAssertNil(BOSSAppearance.resolve("system").colorScheme)
        XCTAssertEqual(BOSSAppearance.resolve("light").colorScheme, .light)
        XCTAssertEqual(BOSSAppearance.resolve("dark").colorScheme, .dark)
    }
    func testPrerequisitesDoNotImplyBackendHealth() {
        for signedIn in [false, true] {
            for hasTeam in [false, true] {
                XCTAssertEqual(BOSSPresentation.battleAvailability(configured: false, signedIn: signedIn, hasTeam: hasTeam), .offline)
            }
        }
        XCTAssertEqual(BOSSPresentation.battleAvailability(configured: true, signedIn: false, hasTeam: true), .signedOut)
        XCTAssertEqual(BOSSPresentation.battleAvailability(configured: true, signedIn: true, hasTeam: false), .noTeam)
        XCTAssertEqual(BOSSPresentation.battleAvailability(configured: true, signedIn: true, hasTeam: true), .ready)
    }
    func testStorageErrorTakesPrecedenceOverPositiveCount() {
        XCTAssertNotNil(BOSSPresentation.saveUnavailableReason(count: 0, storageError: nil))
        XCTAssertNil(BOSSPresentation.saveUnavailableReason(count: 3, storageError: nil))
        XCTAssertEqual(BOSSPresentation.saveUnavailableReason(count: 3, storageError: "disk error"), "保存できません：disk error")
    }
    private func rgb(_ hex: UInt32) -> [Double] {
        [Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)].map { $0 / 255 }
    }
    private func contrast(_ a: [Double], _ b: [Double]) -> Double {
        func luminance(_ rgb: [Double]) -> Double {
            let c = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722
        }
        let l1 = luminance(a), l2 = luminance(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
    func testTextAndBoundariesInBothAppearances() {
        for dark in [false, true] {
            for high in [false, true] {
                for bg in [BOSSPalette.Token.canvas, .surface, .elevated] {
                    let background = rgb(bg.hex(dark: dark, highContrast: high))
                    for fg in [BOSSPalette.Token.primary, .secondary, .cyan, .violet, .success, .warning, .error] {
                        XCTAssertGreaterThanOrEqual(contrast(rgb(fg.hex(dark: dark, highContrast: high)), background), 4.5, "\(fg) on \(bg), dark=\(dark)")
                    }
                    XCTAssertGreaterThanOrEqual(contrast(rgb(BOSSPalette.Token.border.hex(dark: dark, highContrast: high)), background), 3)
                }
            }
        }
    }
    func testButtonGradientIncludingPressedState() {
        for dark in [false, true] {
            let a = rgb(BOSSPalette.Token.actionStart.hex(dark: dark)), b = rgb(BOSSPalette.Token.actionEnd.hex(dark: dark))
            for step in 0...100 {
                let t = Double(step) / 100
                let color = zip(a, b).map { $0 * (1 - t) + $1 * t }
                XCTAssertGreaterThanOrEqual(contrast([1, 1, 1], color), 4.5)
                XCTAssertGreaterThanOrEqual(contrast([1, 1, 1], color.map { $0 * 0.85 }), 4.5)
            }
        }
    }
}
