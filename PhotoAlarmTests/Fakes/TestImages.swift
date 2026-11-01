import CoreGraphics

enum TestImages {
    /// A 1×1 opaque white `CGImage`, enough to feed a fake matcher.
    static func onePixel() -> CGImage {
        guard
            let context = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { preconditionFailure("Could not create a 1×1 bitmap context") }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let image = context.makeImage() else { preconditionFailure("Could not draw the 1×1 test image") }
        return image
    }
}
