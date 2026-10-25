#!/usr/bin/env swift
import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    : root.appendingPathComponent("App/AppIcon.icns")

func drawIcon(size: CGFloat) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 100 / 1024
    let body = canvas.insetBy(dx: inset, dy: inset)
    let radius = body.width * 0.225
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = size * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()
    NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.86, alpha: 1).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    guard let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.33, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.78, alpha: 1),
    ]) else { fatalError("Couldn't make the background gradient") }
    gradient.draw(in: bodyPath, angle: -60)

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()
    guard let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)]) else {
        fatalError("Couldn't make the highlight gradient")
    }
    highlight.draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let unit = body.width / 824
    let lineHeight = 58 * unit
    let left = body.minX + 150 * unit
    let lineWidths: [CGFloat] = [524, 420, 300].map { $0 * unit }
    let tops: [CGFloat] = [610, 470, 330].map { body.minY + $0 * unit }
    NSColor.white.withAlphaComponent(0.95).setFill()
    for (width, y) in zip(lineWidths, tops) {
        NSBezierPath(roundedRect: CGRect(x: left, y: y, width: width, height: lineHeight), xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
    }

    let wave = NSBezierPath()
    let waveY = tops[1] - 34 * unit
    let waveStart = left + 90 * unit
    let waveEnd = left + 360 * unit
    let step = 30 * unit
    wave.move(to: CGPoint(x: waveStart, y: waveY))
    var x = waveStart
    var up = true
    while x < waveEnd {
        let next = min(x + step, waveEnd)
        wave.curve(
            to: CGPoint(x: next, y: waveY),
            controlPoint1: CGPoint(x: x + step / 3, y: waveY + (up ? 16 : -16) * unit),
            controlPoint2: CGPoint(x: next - step / 3, y: waveY + (up ? 16 : -16) * unit)
        )
        x = next
        up.toggle()
    }
    wave.lineWidth = 16 * unit
    wave.lineCapStyle = .round
    NSColor(calibratedRed: 1, green: 0.42, blue: 0.40, alpha: 1).setStroke()
    wave.stroke()

    let badgeSize = 290 * unit
    let badge = CGRect(x: body.maxX - badgeSize - 70 * unit, y: body.minY + 70 * unit, width: badgeSize, height: badgeSize)
    NSGraphicsContext.saveGraphicsState()
    let badgeShadow = NSShadow()
    badgeShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    badgeShadow.shadowBlurRadius = 18 * unit
    badgeShadow.shadowOffset = NSSize(width: 0, height: -6 * unit)
    badgeShadow.set()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: badge).fill()
    NSGraphicsContext.restoreGraphicsState()

    let check = NSBezierPath()
    check.move(to: CGPoint(x: badge.minX + badge.width * 0.27, y: badge.minY + badge.height * 0.52))
    check.line(to: CGPoint(x: badge.minX + badge.width * 0.44, y: badge.minY + badge.height * 0.35))
    check.line(to: CGPoint(x: badge.minX + badge.width * 0.74, y: badge.minY + badge.height * 0.67))
    check.lineWidth = 34 * unit
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor(calibratedRed: 0.12, green: 0.62, blue: 0.42, alpha: 1).setStroke()
    check.stroke()
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
