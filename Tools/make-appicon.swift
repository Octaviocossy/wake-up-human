#!/usr/bin/env swift

// Renders Wake Up Human's app icon — a white `alarm.fill` on an orange squircle — and writes the
// full macOS icon ladder into an asset catalog.
//
//     swift Tools/make-appicon.swift            # writes WakeUpHuman/Assets.xcassets
//     swift Tools/make-appicon.swift <path>     # writes <path> instead
//
// Run this by hand from the repo root and COMMIT THE OUTPUT. CI compiles sources; it does not author
// them. Re-run it only when the artwork constants below change. Every size is rendered from scratch
// rather than downsampled from a 1024 master, so the symbol stays crisp at 16×16 in Finder.

import AppKit
import Foundation

// MARK: - Artwork

/// Fraction of the canvas left empty around the squircle; macOS icons are not edge-to-edge.
let insetRatio: CGFloat = 100.0 / 1024.0

/// Superellipse exponent; n ≈ 5 approximates the continuous corner macOS uses.
let squircleExponent: CGFloat = 5

/// #FF9F0A — the prototype's Alarm and Ring accent (`docs/design/`).
let backgroundColor = NSColor(srgbRed: 255.0 / 255, green: 159.0 / 255, blue: 10.0 / 255, alpha: 1)

let symbolName = "alarm.fill"

/// Symbol box width as a fraction of the squircle's side — tuned by eye.
let symbolRatio: CGFloat = 0.70

// MARK: - Geometry

func squirclePath(in rect: CGRect, exponent n: CGFloat, segments: Int = 720) -> CGPath {
    let a = rect.width / 2
    let b = rect.height / 2
    let path = CGMutablePath()
    for i in 0...segments {
        let t = CGFloat(i) / CGFloat(segments) * 2 * .pi
        let ct = cos(t)
        let st = sin(t)
        let x = rect.midX + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = rect.midY + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// MARK: - Rendering

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-appicon: \(message)\n".utf8))
    exit(1)
}

/// The symbol, tinted white. `.sourceAtop` paints only where the template has coverage.
func whiteSymbol(pointSize: CGFloat) -> NSImage {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        fail("SF Symbol '\(symbolName)' is unavailable.")
    }
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    guard let sized = base.withSymbolConfiguration(configuration) else {
        fail("could not apply a symbol configuration at \(pointSize) pt.")
    }
    sized.isTemplate = true
    return NSImage(size: sized.size, flipped: false) { rect in
        sized.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fail("could not allocate a \(pixels)×\(pixels) bitmap.") }
    rep.size = NSSize(width: pixels, height: pixels)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fail("could not create a drawing context for \(pixels)×\(pixels).")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = CGFloat(pixels)
    let inset = canvas * insetRatio
    let side = canvas - inset * 2
    let box = CGRect(x: inset, y: inset, width: side, height: side)

    let cgContext = context.cgContext
    cgContext.addPath(squirclePath(in: box, exponent: squircleExponent))
    cgContext.setFillColor(backgroundColor.cgColor)
    cgContext.fillPath()

    let target = side * symbolRatio
    let symbol = whiteSymbol(pointSize: target)
    let scale = target / max(symbol.size.width, symbol.size.height)
    let width = symbol.size.width * scale
    let height = symbol.size.height * scale
    symbol.draw(in: NSRect(x: (canvas - width) / 2, y: (canvas - height) / 2, width: width, height: height))
    return rep
}

// MARK: - Asset catalog

let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

func filename(points: Int, scale: Int) -> String {
    let suffix = scale == 1 ? "" : "@\(scale)x"
    return "icon_\(points)x\(points)\(suffix).png"
}

let catalogPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "WakeUpHuman/Assets.xcassets"
let catalogURL = URL(fileURLWithPath: catalogPath)
let iconSetURL = catalogURL.appendingPathComponent("AppIcon.appiconset")

do {
    try FileManager.default.createDirectory(at: iconSetURL, withIntermediateDirectories: true)
    let catalogInfo = #"{\#n  "info" : {\#n    "author" : "xcode",\#n    "version" : 1\#n  }\#n}\#n"#
    try catalogInfo.write(to: catalogURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    var images: [String] = []
    for entry in entries {
        let pixels = entry.points * entry.scale
        let name = filename(points: entry.points, scale: entry.scale)
        guard let png = renderIcon(pixels: pixels).representation(using: .png, properties: [:]) else {
            fail("could not encode \(name) as PNG.")
        }
        try png.write(to: iconSetURL.appendingPathComponent(name))
        images.append("""
                {
                  "filename" : "\(name)",
                  "idiom" : "mac",
                  "scale" : "\(entry.scale)x",
                  "size" : "\(entry.points)x\(entry.points)"
                }
            """)
        print("  \(name)  (\(pixels)×\(pixels))")
    }

    let contents = """
        {
          "images" : [
        \(images.joined(separator: ",\n"))
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """
    try contents.write(to: iconSetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("Wrote \(entries.count) icons to \(iconSetURL.path)")
} catch {
    fail("\(error.localizedDescription)")
}
