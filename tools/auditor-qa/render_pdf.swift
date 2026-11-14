// Read-only rendering of synthetic Kafaa report evidence, with a white page.
import AppKit
import PDFKit
for name in ["en", "ar"] {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let source = root.appendingPathComponent("docs/evidence/auditor/\(name)-attribution.pdf")
    guard let document = PDFDocument(url: source) else { fatalError("Missing synthetic report") }
    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else { fatalError("Missing page") }
        let bounds = page.bounds(for: .mediaBox)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 1.5), pixelsHigh: Int(bounds.height * 1.5), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: 1.5, y: 1.5)
        context.cgContext.setFillColor(NSColor.white.cgColor)
        context.cgContext.fill(bounds)
        page.draw(with: .mediaBox, to: context.cgContext)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let destination = root.appendingPathComponent("docs/evidence/auditor/\(name)-report-page-\(index + 1).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
    }
    print("Rendered \(name): \(document.pageCount) pages")
}
