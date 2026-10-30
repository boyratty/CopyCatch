// OCR.swift
// Reads text from an image using Apple's Vision framework — the same on-device engine
// behind Live Text. Nothing leaves the Mac.

import CoreGraphics
import Vision

enum OCR {
    /// - Parameter fast: quicker, but less reliable on small, faint or handwritten text.
    static func recognizeText(in image: CGImage, fast: Bool) async -> String {
        await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = fast ? .fast : .accurate
            // Telling Vision the language up front is much quicker than letting it detect one.
            request.recognitionLanguages = ["en-GB", "en-US"]
            request.automaticallyDetectsLanguage = false
            request.usesLanguageCorrection = !fast

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return ""
            }
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }
}
