#!/usr/bin/env swift
// Draws the app icon: a bold G with the red squiggle under it, the spellchecker's mark, on a navy tile.
//
//   swift scripts/make-icon.swift                  writes App/AppIcon.icns
//   swift scripts/make-icon.swift OUT.icns         writes it elsewhere
//   swift scripts/make-icon.swift --png OUT.png N  writes one N×N PNG (the website's icon.png and favicon.png)
import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

func drawIcon(size: CGFloat) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    // macOS icons leave a margin around the tile so the shadow fits in the canvas.
    let inset = size * 100 / 1024
    let body = canvas.insetBy(dx: inset, dy: inset)
    let radius = body.width * 0.225
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    let unit = body.width / 824

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = size * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()
    NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.22, alpha: 1).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    guard let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.17, green: 0.22, blue: 0.38, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.19, alpha: 1),
    ]) else { fatalError("Couldn't make the background gradient") }
    gradient.draw(in: bodyPath, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    guard let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)]) else {
        fatalError("Couldn't make the highlight gradient")
    }
    highlight.draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // The letter: a heavy serif G, cream on navy, sitting a little above the middle.
    guard let font = NSFont(name: "Georgia-Bold", size: 560 * unit) ?? NSFont(name: "Times-Bold", size: 560 * unit) else {
        fatalError("No serif font for the letter")
    }
    let letter = NSAttributedString(string: "G", attributes: [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.91, alpha: 1),
    ])
    let letterSize = letter.size()
    let letterX = body.midX - letterSize.width / 2 + 4 * unit
    let baseline = body.minY + 262 * unit
    let letterY = baseline + font.descender
    NSGraphicsContext.saveGraphicsState()
    let letterShadow = NSShadow()
    letterShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    letterShadow.shadowBlurRadius = 10 * unit
    letterShadow.shadowOffset = NSSize(width: 0, height: -6 * unit)
    letterShadow.set()
    letter.draw(at: CGPoint(x: letterX, y: letterY))
    NSGraphicsContext.restoreGraphicsState()

    // The red squiggle under it, as under a misspelt word.
    let wave = NSBezierPath()
    let waveY = baseline - 86 * unit
    let waveStart = letterX + 8 * unit
    let waveEnd = letterX + letterSize.width - 8 * unit
    // Small sizes get fewer, fatter waves so the squiggle survives at 16 px.
    let small = size < 64
    let step = (waveEnd - waveStart) / (small ? 3 : 6)
    let amplitude = small ? 40 * unit : 24 * unit
    wave.move(to: CGPoint(x: waveStart, y: waveY))
    var x = waveStart
    var up = true
    while x < waveEnd - 1 {
        let next = min(x + step, waveEnd)
        wave.curve(
            to: CGPoint(x: next, y: waveY),
            controlPoint1: CGPoint(x: x + step / 3, y: waveY + (up ? amplitude : -amplitude)),
            controlPoint2: CGPoint(x: next - step / 3, y: waveY + (up ? amplitude : -amplitude))
        )
        x = next
        up.toggle()
    }
    wave.lineWidth = small ? max(30 * unit, size * 0.08) : 30 * unit
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    NSColor(calibratedRed: 1, green: 0.30, blue: 0.33, alpha: 1).setStroke()
    wave.stroke()
}

func png(pixels: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Couldn't make a \(pixels)×\(pixels) bitmap") }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Couldn't encode the \(pixels)×\(pixels) icon as PNG")
    }
    return data
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--png" {
    guard arguments.count == 3, let pixels = Int(arguments[2]), pixels > 0 else {
        FileHandle.standardError.write(Data("usage: make-icon.swift --png OUT.png SIZE\n".utf8))
        exit(2)
    }
    let output = URL(fileURLWithPath: arguments[1]).standardizedFileURL
    try png(pixels: pixels).write(to: output)
    print("Wrote \(output.path)")
    exit(0)
}

let output = arguments.first.map { URL(fileURLWithPath: $0).standardizedFileURL }
    ?? root.appendingPathComponent("App/AppIcon.icns")
let fileManager = FileManager.default
let workDir = fileManager.temporaryDirectory.appendingPathComponent("grammar-review-icon-\(UUID().uuidString)")
let iconset = workDir.appendingPathComponent("AppIcon.iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: workDir) }

for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(iconutil.terminationStatus)\n".utf8))
    exit(1)
}

print("Wrote \(output.path)")
