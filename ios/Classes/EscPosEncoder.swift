import Foundation
import UIKit

// MARK: - ESC/POS Command Encoder

/// Comprehensive ESC/POS command encoder for thermal printers.
/// Supports text formatting, barcodes, QR codes, images, and paper/cash drawer control.
public class EscPosEncoder {

    // MARK: - ESC/POS Constants

    public enum Align: UInt8 {
        case left = 0x00
        case center = 0x01
        case right = 0x02
    }

    public enum FontSize: UInt8 {
        case normal = 0x00
        case doubleWidth = 0x20
        case doubleHeight = 0x10
        case doubleBoth = 0x30
    }

    public enum Underline: UInt8 {
        case off = 0x00
        case on1Dot = 0x01
        case on2Dot = 0x02
    }

    public enum BarcodeType: UInt8 {
        case upcA = 0x41       // UPC-A
        case upcE = 0x42       // UPC-E
        case ean13 = 0x43      // JAN13/EAN13
        case ean8 = 0x44       // JAN8/EAN8
        case code39 = 0x45     // CODE39
        case itf = 0x46        // ITF
        case codabar = 0x47    // CODABAR
        case code93 = 0x48     // CODE93
        case code128 = 0x49    // CODE128
    }

    public enum BarcodeTextPosition: UInt8 {
        case none = 0x00
        case above = 0x01
        case below = 0x02
        case both = 0x03
    }

    public enum QrErrorCorrection: UInt8 {
        case low = 0x31        // ~7% recovery
        case medium = 0x32     // ~15% recovery
        case quartile = 0x33   // ~25% recovery
        case high = 0x34       // ~30% recovery
    }

    public enum QrModel: UInt8 {
        case model1 = 0x31
        case model2 = 0x32
    }

    // MARK: - Properties

    private var data = Data()
    private var _width: Int = 48  // Default 384 dots / 8 dots per byte

    /// Printer width in bytes (dots / 8). Default is 48 (384-dot printer).
    public var width: Int {
        get { return _width }
        set { _width = newValue }
    }

    // MARK: - Initialization

    public init(width: Int = 48) {
        self._width = width
        self.data = Data()
    }

    // MARK: - Raw Commands

    /// Initialize printer (ESC @)
    public func initialize() -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x40])
        return self
    }

    /// Print and line feed (LF)
    public func feed() -> EscPosEncoder {
        data.append(0x0A)
        return self
    }

    /// Print and feed n lines (ESC d n)
    public func feedLines(_ lines: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x64, lines])
        return self
    }

    /// Carriage return (CR)
    public func carriageReturn() -> EscPosEncoder {
        data.append(0x0D)
        return self
    }

    // MARK: - Text Commands

    /// Set character code table (ESC t n)
    public func setCodeTable(_ table: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x74, table])
        return self
    }

    /// Set international character set (ESC R n)
    public func setInternationalCharset(_ charset: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x52, charset])
        return self
    }

    /// Select print mode (ESC ! n) - combines bold, double-height, double-width, underline
    public func selectPrintMode(
        font: UInt8 = 0,
        bold: Bool = false,
        doubleHeight: Bool = false,
        doubleWidth: Bool = false,
        underline: Bool = false
    ) -> EscPosEncoder {
        var mode: UInt8 = font
        if bold { mode |= 0x08 }
        if doubleHeight { mode |= 0x10 }
        if doubleWidth { mode |= 0x20 }
        if underline { mode |= 0x80 }
        data.append(contentsOf: [0x1B, 0x21, mode])
        return self
    }

    /// Set character size (GS ! n)
    public func setCharacterSize(heightMultiplier: UInt8, widthMultiplier: UInt8) -> EscPosEncoder {
        let n = ((heightMultiplier - 1) << 4) | (widthMultiplier - 1)
        data.append(contentsOf: [0x1D, 0x21, n])
        return self
    }

    /// Turn on/off emphasized/bold mode (ESC E n)
    public func bold(_ enabled: Bool) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x45, enabled ? 0x01 : 0x00])
        return self
    }

    /// Turn on/off underline mode (ESC - n)
    public func underline(_ style: Underline) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x2D, style.rawValue])
        return self
    }

    /// Turn on/off double-strike mode (ESC G n)
    public func doubleStrike(_ enabled: Bool) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x47, enabled ? 0x01 : 0x00])
        return self
    }

    /// Select font (ESC M n) - 0: Font A, 1: Font B
    public func selectFont(_ fontIndex: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x4D, fontIndex])
        return self
    }

    /// Set absolute print position (ESC $ nL nH)
    public func setPrintPosition(_ col: UInt16) -> EscPosEncoder {
        let nL = UInt8(col & 0xFF)
        let nH = UInt8((col >> 8) & 0xFF)
        data.append(contentsOf: [0x1B, 0x24, nL, nH])
        return self
    }

    /// Set left margin (GS L nL nH)
    public func setLeftMargin(_ col: UInt16) -> EscPosEncoder {
        let nL = UInt8(col & 0xFF)
        let nH = UInt8((col >> 8) & 0xFF)
        data.append(contentsOf: [0x1D, 0x4C, nL, nH])
        return self
    }

    /// Set alignment (ESC a n)
    public func setAlignment(_ align: Align) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x61, align.rawValue])
        return self
    }

    /// Rotate 90 degrees clockwise (ESC V n)
    public func rotate(_ enabled: Bool) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x56, enabled ? 0x01 : 0x00])
        return self
    }

    /// Invert colors (GS B n)
    public func invert(_ enabled: Bool) -> EscPosEncoder {
        data.append(contentsOf: [0x1D, 0x42, enabled ? 0x01 : 0x00])
        return self
    }

    /// Set line spacing (ESC 3 n) in dots
    public func setLineSpacing(_ dots: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x33, dots])
        return self
    }

    /// Default line spacing (ESC 2)
    public func defaultLineSpacing() -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x32])
        return self
    }

    // MARK: - Text Printing

    /// Print raw text
    public func text(_ string: String) -> EscPosEncoder {
        if let encoded = string.data(using: .utf8) {
            data.append(encoded)
        }
        return self
    }

    /// Print text followed by a newline
    public func textLine(_ string: String) -> EscPosEncoder {
        text(string)
        feed()
        return self
    }

    /// Print a row of dashes as a separator line
    public func separator(_ character: Character = "-") -> EscPosEncoder {
        let count = _width * 2
        let line = String(repeating: character, count: count)
        textLine(line)
        return self
    }

    /// Print multiple text lines
    public func textLines(_ lines: [String]) -> EscPosEncoder {
        for line in lines {
            textLine(line)
        }
        return self
    }

    /// Print left-right aligned text on the same line
    public func textLeftRight(left: String, right: String) -> EscPosEncoder {
        let totalWidth = _width * 2
        let leftCount = left.count
        let rightCount = right.count
        let spaceCount = max(0, totalWidth - leftCount - rightCount)

        var line = left
        if spaceCount > 0 {
            line += String(repeating: " ", count: spaceCount)
        }
        line += right
        textLine(line)
        return self
    }

    /// Print a 3-column row
    public func textColumns(_ cols: [String], widths: [Int]) -> EscPosEncoder {
        guard cols.count == widths.count, !cols.isEmpty else { return self }
        let totalWidth = _width * 2

        var result = ""
        for i in 0..<cols.count {
            let colText = cols[i]
            let colWidth = widths[i]
            let padded: String
            if colText.count > colWidth {
                padded = String(colText.prefix(colWidth))
            } else {
                padded = colText + String(repeating: " ", count: colWidth - colText.count)
            }
            result += padded
        }
        textLine(result)
        return self
    }

    // MARK: - Image Printing

    /// Print an image using ESC/POS raster bit image format
    /// - Parameters:
    ///   - image: The UIImage to print
    ///   - maxWidth: Maximum width in dots (default: printer width * 8)
    public func image(_ image: UIImage, maxWidth: Int = 0) -> EscPosEncoder {
        let targetWidth = maxWidth > 0 ? maxWidth : _width * 8

        guard let cgImage = image.cgImage else {
            return self
        }

        let imgWidth = cgImage.width
        let imgHeight = cgImage.height

        // Calculate scaling
        let ratio = CGFloat(targetWidth) / CGFloat(imgWidth)
        let newWidth = targetWidth
        let newHeight = Int(CGFloat(imgHeight) * ratio)

        guard newWidth > 0, newHeight > 0 else { return self }

        // Create a new context with the target size
        guard let colorSpace = cgImage.colorSpace else { return self }
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return self }

        // Scale and draw into context
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let imageData = context.data else { return self }
        let pixels = imageData.bindMemory(to: UInt8.self, capacity: newWidth * newHeight)

        // Convert to monochrome bitmap
        // Each row is stored as bytes where each bit represents a pixel
        let rowBytes = (newWidth + 7) / 8

        // Set print density
        // GS ( E 3 0 p m fn1 fn2 (density) - simplified, skip for compatibility

        var imageCommands = Data()

        for y in 0..<newHeight {
            var rowBits = [UInt8](repeating: 0, count: rowBytes)

            for x in 0..<newWidth {
                let pixelIndex = y * newWidth + x
                let gray = pixels[pixelIndex]

                // Threshold at 127 for monochrome
                let isBlack = gray < 127
                if isBlack {
                    let byteIndex = x / 8
                    let bitIndex = 7 - (x % 8)
                    rowBits[byteIndex] |= (1 << bitIndex)
                }
            }

            imageCommands.append(contentsOf: rowBits)
        }

        // Use GS v 0 (raster bit image mode)
        let xl = UInt8(newWidth & 0xFF)
        let xh = UInt8((newWidth >> 8) & 0xFF)
        let yl = UInt8(newHeight & 0xFF)
        let yh = UInt8((newHeight >> 8) & 0xFF)

        // GS v 0 m=0 (normal), xl, xh, yl, yh, d1...dk
        imageCommands.insert(contentsOf: [0x1D, 0x76, 0x30, 0x00, xl, xh, yl, yh], at: 0)

        data.append(imageCommands)
        return self
    }

    /// Print an image from Data (PNG/JPEG) by decoding first
    public func imageData(_ imageData: Data, maxWidth: Int = 0) -> EscPosEncoder {
        if let uiImage = UIImage(data: imageData) {
            return image(uiImage, maxWidth: maxWidth)
        }
        return self
    }

    // MARK: - Barcode Printing

    /// Print a barcode using ESC/POS barcode command
    /// - Parameters:
    ///   - type: Barcode type (BarcodeType)
    ///   - data: Barcode data string
    ///   - width: Module width (2-6, default 2)
    ///   - height: Bar height in dots (1-255, default 162)
    ///   - textPosition: HRI text position
    ///   - textFont: HRI font (0: Font A, 1: Font B)
    public func barcode(
        type: BarcodeType,
        data: String,
        width: UInt8 = 2,
        height: UInt8 = 162,
        textPosition: BarcodeTextPosition = .below,
        textFont: UInt8 = 0
    ) -> EscPosEncoder {
        // GS H n - set barcode height
        self.data.append(contentsOf: [0x1D, 0x48, height])

        // GS w n - set barcode module width
        self.data.append(contentsOf: [0x1D, 0x77, width])

        // GS f n - set HRI font
        self.data.append(contentsOf: [0x1D, 0x66, textFont])

        // GS H n - set HRI character print position
        self.data.append(contentsOf: [0x1D, 0x48, height])

        // GS k m n d1...dk - print barcode
        // m = barcode type
        // n = data length
        self.data.append(contentsOf: [0x1D, 0x6B, type.rawValue])

        if let encodedData = data.data(using: .ascii) {
            let length = UInt8(min(encodedData.count, 255))
            self.data.append(length)
            self.data.append(encodedData)
        }

        feed()
        return self
    }

    /// Print a barcode with simplified parameters (for Flutter method call)
    public func printBarcode(
        type: String,
        content: String,
        width: Int = 2,
        height: Int = 162,
        textPosition: Int = 2,
        font: Int = 0
    ) -> EscPosEncoder {
        let barcodeType: BarcodeType
        switch type.uppercased() {
        case "UPC_A": barcodeType = .upcA
        case "UPC_E": barcodeType = .upcE
        case "EAN13", "JAN13": barcodeType = .ean13
        case "EAN8", "JAN8": barcodeType = .ean8
        case "CODE39": barcodeType = .code39
        case "ITF": barcodeType = .itf
        case "CODABAR": barcodeType = .codabar
        case "CODE93": barcodeType = .code93
        case "CODE128": barcodeType = .code128
        default: barcodeType = .code128
        }

        let pos = BarcodeTextPosition(rawValue: UInt8(textPosition)) ?? .below
        return barcode(
            type: barcodeType,
            data: content,
            width: UInt8(min(width, 6)),
            height: UInt8(min(height, 255)),
            textPosition: pos,
            textFont: UInt8(font)
        )
    }

    // MARK: - QR Code Printing

    /// Print a QR code using ESC/POS QR command set
    /// - Parameters:
    ///   - content: QR code data string
    ///   - size: Module size (1-16, default 6)
    ///   - errorCorrection: Error correction level
    ///   - model: QR model (default model2)
    public func qrCode(
        content: String,
        size: UInt8 = 6,
        errorCorrection: QrErrorCorrection = .medium,
        model: QrModel = .model2
    ) -> EscPosEncoder {
        guard let encodedData = content.data(using: .utf8) else { return self }
        let pL = UInt8(encodedData.count & 0xFF)
        let pH = UInt8((encodedData.count >> 8) & 0xFF)

        // Step 1: Select QR model
        // GS ( k pL pH cn fn n
        data.append(contentsOf: [
            0x1D, 0x28, 0x6B,
            0x04, 0x00,  // pL, pH (parameter length)
            0x31,        // cn = 49 (QR code)
            0x41,        // fn = 65 (select model)
            model.rawValue,  // n: model selection
            0x00         // m: reserved
        ])

        // Step 2: Set QR module size
        // GS ( k pL pH cn fn n
        data.append(contentsOf: [
            0x1D, 0x28, 0x6B,
            0x03, 0x00,  // pL, pH
            0x31,        // cn = 49
            0x43,        // fn = 67 (set module size)
            size         // n: module size
        ])

        // Step 3: Set error correction level
        // GS ( k pL pH cn fn n
        data.append(contentsOf: [
            0x1D, 0x28, 0x6B,
            0x03, 0x00,  // pL, pH
            0x31,        // cn = 49
            0x45,        // fn = 69 (set error correction)
            errorCorrection.rawValue
        ])

        // Step 4: Store data
        // GS ( k pL pH cn fn m d1...dk
        data.append(contentsOf: [
            0x1D, 0x28, 0x6B,
            pL, pH,      // data length
            0x31,        // cn = 49
            0x50,        // fn = 80 (store data)
            0x30         // m = 48
        ])
        data.append(encodedData)

        // Step 5: Print QR code
        // GS ( k pL pH cn fn m
        data.append(contentsOf: [
            0x1D, 0x28, 0x6B,
            0x03, 0x00,  // pL, pH
            0x31,        // cn = 49
            0x51,        // fn = 81 (print)
            0x30         // m = 48
        ])

        feed()
        return self
    }

    /// Print QR code with simplified parameters (for Flutter method call)
    public func printQrCode(
        content: String,
        size: Int = 6,
        errorCorrection: String = "M"
    ) -> EscPosEncoder {
        let ec: QrErrorCorrection
        switch errorCorrection.uppercased() {
        case "L": ec = .low
        case "M": ec = .medium
        case "Q": ec = .quartile
        case "H": ec = .high
        default: ec = .medium
        }
        return qrCode(
            content: content,
            size: UInt8(min(max(size, 1), 16)),
            errorCorrection: ec
        )
    }

    // MARK: - Cash Drawer

    /// Open cash drawer (ESC p m t1 t2)
    /// - Parameters:
    ///   - pin: Drawer pin (0 or 1)
    ///   - duration: Pulse duration in ms (typically 100-300)
    public func openCashDrawer(pin: UInt8 = 0, duration: UInt8 = 100) -> EscPosEncoder {
        let t1 = UInt8(duration / 2)
        let t2 = UInt8(duration / 2)
        data.append(contentsOf: [0x1B, 0x70, pin, t1, t2])
        return self
    }

    // MARK: - Paper Cutting

    /// Cut paper (GS V m n)
    /// - Parameters:
    ///   - partial: If true, partial cut; if false, full cut
    ///   - feed: Number of lines to feed before cutting
    public func cut(partial: Bool = false, feed: UInt8 = 3) -> EscPosEncoder {
        feedLines(feed)
        if partial {
            // GS V 66 m
            data.append(contentsOf: [0x1D, 0x56, 0x42, 0x00])
        } else {
            // GS V 65 m
            data.append(contentsOf: [0x1D, 0x56, 0x41])
        }
        return self
    }

    // MARK: - Status Commands

    /// Real-time status request (DLE EOT n)
    /// n: 1=printer status, 2=offline status, 3=error status, 4=paper roll sensor
    public func requestStatus(_ type: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x10, 0x04, type])
        return self
    }

    /// Enable/disable automatic status back (ESC u n)
    /// n: 1=enable printer status, 2=enable offline status, 3=enable error status, 4=enable paper sensor, 0=disable all
    public func enableAutoStatusBack(_ mode: UInt8) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x75, mode])
        return self
    }

    // MARK: - Miscellaneous

    /// Transmit peripheral device status (ESC v)
    public func transmitPeripheralStatus() -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x76])
        return self
    }

    /// Generate pulse (ESC BEL - buzzer)
    public func buzzer(_ count: UInt8 = 1, duration: UInt8 = 3) -> EscPosEncoder {
        data.append(contentsOf: [0x1B, 0x42, count, duration])
        return self
    }

    /// Get the encoded data
    public func build() -> Data {
        return data
    }

    /// Clear all encoded data
    public func reset() {
        data = Data()
    }

    /// Append raw bytes
    public func raw(_ bytes: [UInt8]) -> EscPosEncoder {
        data.append(contentsOf: bytes)
        return self
    }

    /// Append raw Data
    public func rawData(_ rawData: Data) -> EscPosEncoder {
        data.append(rawData)
        return self
    }

    // MARK: - Receipt Builder Helpers

    /// Print a formatted receipt header with centered text and separator
    public func receiptHeader(_ title: String, subtitle: String = "") -> EscPosEncoder {
        setAlignment(.center)
        bold(true)
        setCharacterSize(heightMultiplier: 2, widthMultiplier: 2)
        textLine(title)
        setCharacterSize(heightMultiplier: 1, widthMultiplier: 1)
        bold(false)
        if !subtitle.isEmpty {
            textLine(subtitle)
        }
        separator()
        return self
    }

    /// Print a receipt footer with separator and centered text
    public func receiptFooter(_ lines: [String]) -> EscPosEncoder {
        separator()
        setAlignment(.center)
        for line in lines {
            textLine(line)
        }
        setAlignment(.left)
        feedLines(2)
        return self
    }

    /// Print a table row with columns
    public func tableRow(columns: [(text: String, width: Int, align: Align)]) -> EscPosEncoder {
        let totalWidth = _width * 2
        var totalColWidth = columns.reduce(0) { $0 + $1.width }
        if totalColWidth > totalWidth {
            totalColWidth = totalWidth
        }

        var row = ""
        for (index, col) in columns.enumerated() {
            let maxChars = col.width
            var text = col.text

            // Truncate if too long
            if text.count > maxChars {
                text = String(text.prefix(maxChars))
            }

            // Pad based on alignment
            switch col.align {
            case .right:
                text = String(repeating: " ", count: maxChars - text.count) + text
            case .center:
                let pad = maxChars - text.count
                let leftPad = pad / 2
                let rightPad = pad - leftPad
                text = String(repeating: " ", count: leftPad) + text + String(repeating: " ", count: rightPad)
            default:
                text = text + String(repeating: " ", count: maxChars - text.count)
            }

            // Last column might be shorter, don't pad
            if index == columns.count - 1 {
                row += text
            } else {
                row += text
            }
        }

        textLine(row)
        return self
    }
}

// MARK: - ESC/POS Command Constants (for reference)

public struct EscPosConstants {
    public static let ESC: UInt8 = 0x1B
    public static let GS: UInt8 = 0x1D
    public static let DLE: UInt8 = 0x10
    public static let FS: UInt8 = 0x1C
    public static let LF: UInt8 = 0x0A
    public static let CR: UInt8 = 0x0D
    public static let NUL: UInt8 = 0x00

    // Common service UUIDs for BLE thermal printers
    public static let printerServiceUUIDs: [String] = [
        "000018F0-0000-1000-8000-00805F9B34FB", // Common printer service
        "0000FF00-0000-1000-8000-00805F9B34FB", // Custom printer service
        "0000FF01-0000-1000-8000-00805F9B34FB", // Another common service
        "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2", // Zebra printer service
        "0000FEFD-0000-1000-8000-00805F9B34FB"  // Generic
    ]
}
