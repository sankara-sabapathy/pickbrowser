import AppKit

// Render installer artwork without launching or controlling Finder.
let size = NSSize(width: 600, height: 380)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
func centered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    (text as NSString).draw(in: NSRect(x: 30, y: y, width: 540, height: 36), withAttributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: style
    ])
}
centered("Install PickBrowser", y: 300, font: .systemFont(ofSize: 25, weight: .semibold), color: .black)
centered("Drag PickBrowser to Applications", y: 269, font: .systemFont(ofSize: 14), color: .darkGray)
let arrow = NSBezierPath()
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 270, y: 190))
arrow.line(to: NSPoint(x: 330, y: 190))
arrow.move(to: NSPoint(x: 319, y: 201))
arrow.line(to: NSPoint(x: 330, y: 190))
arrow.line(to: NSPoint(x: 319, y: 179))
NSColor.gray.setStroke()
arrow.stroke()
centered("Then eject this disk and launch from Applications.", y: 45,
         font: .systemFont(ofSize: 13), color: .darkGray)
image.unlockFocus()
guard CommandLine.arguments.count == 2, let data = image.tiffRepresentation else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
