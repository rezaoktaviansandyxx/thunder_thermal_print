package id.thunderlab.thuder_thermal_print.utils

import android.graphics.Bitmap
import android.graphics.Color
import android.util.Log
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.util.zip.CRC32

/**
 * EscPosEncoder provides ESC/POS command encoding for thermal printers.
 *
 * Supports:
 * - Printer initialization and reset
 * - Text formatting (bold, underline, alignment, size)
 * - Line feeds and paper cutting
 * - QR code printing (model 2)
 * - Barcode printing (CODE128, EAN13, CODE39, UPC-A, etc.)
 * - Image printing with dithering and raster format conversion
 *
 * ESC/POS reference: https://reference.epson-biz.com/modules/ref_escpos/
 */
class EscPosEncoder {

    companion object {
        private const val TAG = "EscPosEncoder"

        // ESC/POS control characters
        private const val ESC: Byte = 0x1B
        private const val GS: Byte = 0x1D
        private const val FS: Byte = 0x1C

        // Line width (bytes per row) - most thermal printers are 384 or 576 pixels wide
        private const val PRINTER_LINE_WIDTH_58MM = 384
        private const val PRINTER_LINE_WIDTH_80MM = 576

        // Default charset
        private val DEFAULT_CHARSET: Charset = Charsets.ISO_8859_1
    }

    private val buffer = ByteArrayOutputStream()

    // ==========================
    // Printer Commands
    // ==========================

    /**
     * ESC @ - Initialize printer.
     * Resets the printer to its default settings.
     */
    fun initialize(): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x40))
        return buffer.toByteArray()
    }

    /**
     * Reset printer and clear buffer.
     */
    fun reset(): ByteArray {
        buffer.reset()
        return initialize()
    }

    // ==========================
    // Text Formatting
    // ==========================

    /**
     * ESC E n - Select bold mode.
     * @param enabled true to enable bold, false to disable
     */
    fun bold(enabled: Boolean): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x45, if (enabled) 0x01 else 0x00))
        return buffer.toByteArray()
    }

    /**
     * ESC - n - Select underline mode.
     * @param mode 0 = off, 1 = underline 1-dot, 2 = underline 2-dot
     */
    fun underline(mode: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x2D, mode.toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC a n - Select justification.
     * @param align 0 = left, 1 = center, 2 = right
     */
    fun align(align: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x61, align.toByte()))
        return buffer.toByteArray()
    }

    /**
     * GS ! n - Select character size.
     * @param widthMultiplier Width multiplier (1-8)
     * @param heightMultiplier Height multiplier (1-8)
     */
    fun charSize(widthMultiplier: Int, heightMultiplier: Int): ByteArray {
        val w = (widthMultiplier - 1).coerceIn(0, 7)
        val h = ((heightMultiplier - 1) shl 4).coerceIn(0, 112)
        buffer.write(byteArrayOf(GS, 0x21, (w or h).toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC M n - Select character font.
     * @param font 0 = font A (default), 1 = font B
     */
    fun font(font: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x4D, font.toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC G n - Select double-strike mode.
     * @param enabled true to enable, false to disable
     */
    fun doubleStrike(enabled: Boolean): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x47, if (enabled) 0x01 else 0x00))
        return buffer.toByteArray()
    }

    /**
     * ESC SP n - Set character spacing.
     * @param spacing Right-side character spacing (0-255)
     */
    fun charSpacing(spacing: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x20, spacing.toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC V n - Set line spacing.
     * @param spacing Vertical line spacing in dots
     */
    fun lineSpacing(spacing: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x33, spacing.toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC 2 - Set default line spacing.
     */
    fun defaultLineSpacing(): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x32))
        return buffer.toByteArray()
    }

    /**
     * GS B n - Select reverse printing (white on black).
     * @param enabled true to enable, false to disable
     */
    fun reverse(enabled: Boolean): ByteArray {
        buffer.write(byteArrayOf(GS, 0x42, if (enabled) 0x01 else 0x00))
        return buffer.toByteArray()
    }

    /**
     * GS H n - Select printing position for horizontal and vertical motion units.
     * Not commonly used, included for completeness.
     */

    /**
     * ESC t n - Select code table / character set.
     * @param codeTable Code table number (0-19)
     */
    fun codeTable(codeTable: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x74, codeTable.toByte()))
        return buffer.toByteArray()
    }

    /**
     * FS . n - Select Kanji character mode.
     * @param mode 0 = normal, 1 = rotated 90 degrees
     */
    fun kanjiMode(mode: Int): ByteArray {
        buffer.write(byteArrayOf(FS, 0x2E, mode.toByte()))
        return buffer.toByteArray()
    }

    // ==========================
    // Line Feed / Paper Control
    // ==========================

    /**
     * ESC d n - Print and feed paper n lines.
     * @param lines Number of lines to feed (0-255)
     */
    fun feed(lines: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x64, lines.toByte()))
        return buffer.toByteArray()
    }

    /**
     * ESC J n - Print and feed paper n lines (reverse).
     * @param dots Number of vertical motion units
     */
    fun reverseFeed(dots: Int): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x6A, dots.toByte()))
        return buffer.toByteArray()
    }

    /**
     * LF - Line feed (1 line).
     */
    fun lineFeed(): ByteArray {
        buffer.write(0x0A)
        return buffer.toByteArray()
    }

    /**
     * GS V m - Cut paper.
     * @param partial true for partial cut (with feed), false for full cut
     */
    fun cut(partial: Boolean): ByteArray {
        if (partial) {
            // GS V 66 3 - Partial cut with feed
            buffer.write(byteArrayOf(GS, 0x56, 0x01))
        } else {
            // GS V 1 - Full cut
            buffer.write(byteArrayOf(GS, 0x56, 0x00))
        }
        return buffer.toByteArray()
    }

    // ==========================
    // Text Output
    // ==========================

    /**
     * Print text string.
     * @param text The text to print
     */
    fun text(text: String): ByteArray {
        buffer.write(text.toByteArray(DEFAULT_CHARSET))
        return buffer.toByteArray()
    }

    /**
     * Print text followed by a line feed.
     * @param text The text to print
     */
    fun textLine(text: String): ByteArray {
        buffer.write(text.toByteArray(DEFAULT_CHARSET))
        buffer.write(0x0A)
        return buffer.toByteArray()
    }

    /**
     * Print a horizontal line (row of dashes).
     * @param character The character to repeat (default '-')
     * @param width Number of characters (default 32)
     */
    fun horizontalLine(character: Char = '-', width: Int = 32): ByteArray {
        buffer.write(character.toString().repeat(width).toByteArray(DEFAULT_CHARSET))
        buffer.write(0x0A)
        return buffer.toByteArray()
    }

    // ==========================
    // QR Code
    // ==========================

    /**
     * Print a QR code using the ESC/POS QR code commands.
     *
     * Command sequence:
     * 1. GS ( k fn m d1...dk p1 p2 [cn rn d1...dn] - Set QR code data
     * 2. GS ( k fn m n - Print QR code
     *
     * @param data The data to encode in the QR code
     * @param size Module size (1-16, recommended 4-8)
     * @param errorCorrection Error correction level: 48=L, 49=M, 50=Q, 51=H
     */
    fun qrCode(data: String, size: Int = 6, errorCorrection: Int = 49): ByteArray {
        val moduleSize = size.coerceIn(1, 16).toByte()

        // Step 1: Select QR code model (model 2)
        // GS ( k fn 65 0 m n [p1 p2 d1...dk]
        // fn = 65, m = 65 (model select), n = 2 (parameter pL pH follow)
        // pL pH = 0, 0
        buffer.write(byteArrayOf(
            GS, 0x28, 0x6B,
            0x03, 0x00, // pL, pH (3 bytes follow)
            0x31, 0x43, // function 49, model 2
            0x02 // set model to 2
        ))

        // Step 2: Set module size
        buffer.write(byteArrayOf(
            GS, 0x28, 0x6B,
            0x03, 0x00, // pL, pH (3 bytes follow)
            0x31, 0x43, // function 49, set module size
            moduleSize
        ))

        // Step 3: Set error correction level
        buffer.write(byteArrayOf(
            GS, 0x28, 0x6B,
            0x03, 0x00, // pL, pH (3 bytes follow)
            0x31, 0x45, // function 49, set error correction
            errorCorrection.toByte()
        ))

        // Step 4: Store the data
        val dataBytes = data.toByteArray(DEFAULT_CHARSET)
        val dataLength = dataBytes.size + 3 // +3 for the header bytes
        buffer.write(byteArrayOf(
            GS, 0x28, 0x6B,
            (dataLength and 0xFF).toByte(), // pL (low byte of length)
            ((dataLength shr 8) and 0xFF).toByte(), // pH (high byte of length)
            0x31, 0x50, // function 49, store data
            dataLength.toByte() // length of data
        ))
        buffer.write(dataBytes)

        // Step 5: Print QR code
        buffer.write(byteArrayOf(
            GS, 0x28, 0x6B,
            0x03, 0x00, // pL, pH (3 bytes follow)
            0x31, 0x51, // function 49, print QR code
            0x30 // print
        ))

        return buffer.toByteArray()
    }

    // ==========================
    // Barcode
    // ==========================

    /**
     * Print a barcode using ESC/POS barcode commands.
     *
     * Barcode types:
     * - 65: UPC-A
     * - 66: UPC-E
     * - 67: JAN13/EAN13
     * - 68: JAN8/EAN8
     * - 69: CODE39
     * - 70: ITF
     * - 71: CODABAR
     * - 72: CODE93
     * - 73: CODE128
     *
     * @param data The data to encode
     * @param type Barcode type (see above)
     * @param width Bar width (2-6, recommended 2-3)
     * @param height Bar height (1-255, recommended 50-100)
     * @param font Position of HRI characters: 0=not printed, 1=above, 2=below, 3=both
     */
    fun barcode(
        data: String,
        type: Int = 73,
        width: Int = 2,
        height: Int = 100,
        font: Int = 2
    ): ByteArray {
        val dataBytes = data.toByteArray(DEFAULT_CHARSET)
        val dataLength = dataBytes.size

        // GS h n - Set barcode height
        buffer.write(byteArrayOf(GS, 0x68, height.toByte()))

        // GS w n - Set barcode width
        buffer.write(byteArrayOf(GS, 0x77, width.toByte()))

        // GS f n - Set HRI character print position
        buffer.write(byteArrayOf(GS, 0x66, font.toByte()))

        // GS k m n d1...dk - Print barcode
        // m = barcode type
        // For CODE128 and similar, use: GS k m n d1...dk where m < 65 for fixed length
        // or m >= 65 for variable length

        if (type >= 65) {
            // Variable-length barcode types (UPC-A, EAN13, etc.)
            // GS k m d1...dk NUL
            buffer.write(byteArrayOf(GS, 0x6B, type.toByte()))
            buffer.write(dataBytes)
            buffer.write(0x00) // NUL terminator
        } else {
            // Fixed-length barcode types (CODE128, CODE39, etc.)
            // GS k m n d1...dk
            buffer.write(byteArrayOf(GS, 0x6B, type.toByte(), dataLength.toByte()))
            buffer.write(dataBytes)
        }

        return buffer.toByteArray()
    }

    // ==========================
    // Image Printing
    // ==========================

    /**
     * Print a bitmap image in ESC/POS raster format.
     *
     * The image is:
     * 1. Scaled to fit within maxWidth
     * 2. Converted to grayscale
     * 3. Dithered using Floyd-Steinberg algorithm
     * 4. Encoded as ESC/POS raster bit image
     *
     * Command: GS v 0 m xL xH yL yH d1...dk
     *
     * @param bitmap The source image
     * @param maxWidth Maximum print width in pixels (default 384 for 58mm paper)
     * @param dithering Whether to apply Floyd-Steinberg dithering (default true)
     * @return ESC/POS encoded byte array
     */
    fun image(bitmap: Bitmap, maxWidth: Int = PRINTER_LINE_WIDTH_58MM, dithering: Boolean = true): ByteArray {
        // Scale the bitmap to fit the printer width
        val scaledBitmap = scaleBitmap(bitmap, maxWidth)
        Log.d(TAG, "Printing image: original=${bitmap.width}x${bitmap.height}, " +
                "scaled=${scaledBitmap.width}x${scaledBitmap.height}")

        // Convert to grayscale and dither
        val width = scaledBitmap.width
        val height = scaledBitmap.height

        // Get pixel data
        val pixels = IntArray(width * height)
        scaledBitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        // Convert to grayscale
        val grayscale = IntArray(width * height)
        for (i in pixels.indices) {
            val pixel = pixels[i]
            val r = Color.red(pixel)
            val g = Color.green(pixel)
            val b = Color.blue(pixel)
            val a = Color.alpha(pixel)

            // Weighted grayscale
            grayscale[i] = if (a < 128) {
                255 // Treat transparent as white
            } else {
                (0.299 * r + 0.587 * g + 0.114 * b).toInt()
            }
        }

        // Apply dithering if enabled
        val binaryPixels = if (dithering) {
            floydSteinbergDither(grayscale, width, height)
        } else {
            // Simple threshold at 128
            grayscale.map { if (it < 128) 0 else 255 }.toIntArray()
        }

        // Calculate bytes per row (8 pixels per byte)
        val bytesPerRow = (width + 7) / 8

        // GS * m nL nH d1...dk - Select bit image mode
        // m = 0 (normal), 1 (double width), 2 (double height), 3 (quadruple)
        // nL nH = total bytes per row (low byte, high byte)
        val totalBytes = bytesPerRow * height

        buffer.write(byteArrayOf(
            GS, 0x76, 0x30, // GS v 0 (print raster bit image, normal mode)
            0x00,           // m = 0 (normal)
            (bytesPerRow and 0xFF).toByte(),       // xL
            ((bytesPerRow shr 8) and 0xFF).toByte(), // xH
            (height and 0xFF).toByte(),             // yL
            ((height shr 8) and 0xFF).toByte()      // yH
        ))

        // Encode each row as a series of bytes
        for (y in 0 until height) {
            for (xByte in 0 until bytesPerRow) {
                var byte = 0
                for (bit in 0..7) {
                    val xPixel = xByte * 8 + bit
                    if (xPixel < width) {
                        val isBlack = binaryPixels[y * width + xPixel] == 0
                        if (isBlack) {
                            byte = byte or (0x80 shr bit)
                        }
                    }
                }
                buffer.write(byte)
            }
        }

        // Clean up scaled bitmap
        if (scaledBitmap != bitmap) {
            scaledBitmap.recycle()
        }

        Log.d(TAG, "Image encoded: ${buffer.size()} bytes total (${bytesPerRow}x$height raster)")

        return buffer.toByteArray()
    }

    /**
     * Scale a bitmap to fit within maxWidth while preserving aspect ratio.
     */
    private fun scaleBitmap(bitmap: Bitmap, maxWidth: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        if (width <= maxWidth) {
            return bitmap
        }

        val scale = maxWidth.toFloat() / width.toFloat()
        val newWidth = maxWidth
        val newHeight = (height * scale).toInt()

        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    /**
     * Apply Floyd-Steinberg dithering to a grayscale image.
     * Converts grayscale values to binary (black/white) using error diffusion.
     *
     * @param grayscale Input grayscale array (0-255, 0=black, 255=white)
     * @param width Image width
     * @param height Image height
     * @return Binary array (0=black, 255=white)
     */
    private fun floydSteinbergDither(grayscale: IntArray, width: Int, height: Int): IntArray {
        // Work on a mutable copy (using Float for error diffusion)
        val data = FloatArray(grayscale.size) { grayscale[it].toFloat() }
        val result = IntArray(grayscale.size) { 255 } // Default white

        for (y in 0 until height) {
            for (x in 0 until width) {
                val oldPixel = data[y * width + x]
                val newPixel = if (oldPixel < 128.0f) 0.0f else 255.0f
                val error = oldPixel - newPixel

                result[y * width + x] = newPixel.toInt()

                // Diffuse error to neighboring pixels
                if (x + 1 < width) {
                    data[y * width + x + 1] += error * 7.0f / 16.0f
                }
                if (y + 1 < height) {
                    if (x - 1 >= 0) {
                        data[(y + 1) * width + (x - 1)] += error * 3.0f / 16.0f
                    }
                    data[(y + 1) * width + x] += error * 5.0f / 16.0f
                    if (x + 1 < width) {
                        data[(y + 1) * width + (x + 1)] += error * 1.0f / 16.0f
                    }
                }
            }
        }

        return result
    }

    // ==========================
    // Cash Drawer
    // ==========================

    /**
     * Pulse the cash drawer kick connector.
     * @param pin Connector pin (0 or 1)
     * @param duration Pulse duration in 2ms units (default 100 = 200ms)
     */
    fun cashDrawer(pin: Int = 0, duration: Int = 100): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x70, pin.toByte(), duration.toByte()))
        return buffer.toByteArray()
    }

    // ==========================
    // Status / Diagnostic
    // ==========================

    /**
     * ESC v - Transmit printer status (real-time).
     */
    fun transmitStatus(): ByteArray {
        buffer.write(byteArrayOf(ESC, 0x76))
        return buffer.toByteArray()
    }

    /**
     * DLE EOT n - Generate pulse in real-time at pin n.
     */
    fun pulseRealTime(pin: Int = 0, durationMs: Int = 100): ByteArray {
        buffer.write(byteArrayOf(0x10, 0x14, pin.toByte(), (durationMs / 2).toByte()))
        return buffer.toByteArray()
    }

    // ==========================
    // Utility
    // ==========================

    /**
     * Get the current buffer contents.
     */
    fun getBytes(): ByteArray {
        return buffer.toByteArray()
    }

    /**
     * Clear the internal buffer.
     */
    fun clear() {
        buffer.reset()
    }

    /**
     * Get the current buffer size.
     */
    fun size(): Int {
        return buffer.size()
    }

    // ==========================
    // Pre-formatted Receipt Helpers
    // ==========================

    /**
     * Create a formatted header section for a receipt.
     */
    fun receiptHeader(storeName: String, address: String?, phone: String?): ByteArray {
        buffer.write(align(1)) // center
        buffer.write(bold(true))
        buffer.write(text(storeName))
        buffer.write(bold(false))
        address?.let { buffer.write(text(it)) }
        phone?.let { buffer.write(text(it)) }
        buffer.write(horizontalLine('=', 32))
        buffer.write(align(0)) // reset to left
        return buffer.toByteArray()
    }

    /**
     * Create a formatted footer section for a receipt.
     */
    fun receiptFooter(message: String? = null, cutPaper: Boolean = true): ByteArray {
        buffer.write(horizontalLine('=', 32))
        message?.let {
            buffer.write(align(1)) // center
            buffer.write(text(it))
        }
        buffer.write(feed(3))
        if (cutPaper) {
            buffer.write(cut(true))
        }
        buffer.write(align(0)) // reset
        return buffer.toByteArray()
    }

    /**
     * Create a table row with left and right aligned text.
     * Pads the space between with dots or spaces.
     */
    fun tableRow(left: String, right: String, width: Int = 32, padChar: Char = ' '): ByteArray {
        val totalLength = left.length + right.length
        if (totalLength >= width) {
            buffer.write(text("$left $right"))
            buffer.write(lineFeed())
        } else {
            val padding = width - totalLength
            buffer.write(text(left + padChar.toString().repeat(padding) + right))
            buffer.write(lineFeed())
        }
        return buffer.toByteArray()
    }
}
