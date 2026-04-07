import Foundation
import Vision
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(CoreVideo)
import CoreVideo
#endif
#if canImport(CoreMedia)
import CoreMedia
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionCamera)
import VisionCamera
#endif

struct PaymentCardScanOptions {
  let scanExpiry: Bool
  let restrictToBrands: [String]

  init(scanExpiry: Bool = true, restrictToBrands: [String] = []) {
    self.scanExpiry = scanExpiry
    self.restrictToBrands = restrictToBrands
  }
}

struct PaymentCardScanResult {
  var pan: String?
  var last4: String?
  var expiryMonth: Int?
  var expiryYear: Int?
  var brand: String?
  var cardholderName: String?
  var complete: Bool

  func toDictionary() -> [String: Any] {
    var dictionary: [String: Any] = [
      "complete": complete,
    ]

    if let pan {
      dictionary["pan"] = pan
    }
    if let last4 {
      dictionary["last4"] = last4
    }
    if let expiryMonth {
      dictionary["expiryMonth"] = expiryMonth
    }
    if let expiryYear {
      dictionary["expiryYear"] = expiryYear
    }
    if let brand {
      dictionary["brand"] = brand
    }
    if let cardholderName {
      dictionary["cardholderName"] = cardholderName
    }

    return dictionary
  }
}

final class PaymentCardScannerPlugin {
  private let parser = CardParser()
  private let luhn = Luhn()
  private let brandDetector = BrandDetector()
  #if canImport(CoreImage)
  private let ciContext = CIContext(options: nil)
  #endif

  func isSupported() -> Bool {
    return true
  }

  func scanCard(options: PaymentCardScanOptions = PaymentCardScanOptions()) -> PaymentCardScanResult {
    _ = options
    return PaymentCardScanResult(complete: false)
  }

  func scanPaymentCard(frame: Any, options: PaymentCardScanOptions = PaymentCardScanOptions()) -> PaymentCardScanResult? {
    guard let image = makeVisionImage(from: frame) else {
      return nil
    }

    return scanPaymentCard(image: image, options: options)
  }

  fileprivate func scanPaymentCard(image: VisionImageSource, options: PaymentCardScanOptions = PaymentCardScanOptions()) -> PaymentCardScanResult {
    let rectangleObservation = detectCardRectangle(in: image)
    let recognizedTexts = recognizeText(in: image, regionOfInterest: rectangleObservation?.boundingBox)

    guard !recognizedTexts.isEmpty else {
      return PaymentCardScanResult(complete: false)
    }

    return buildScanResult(fromRecognizedTexts: recognizedTexts, options: options)
  }

  func makeRectangleRequest() -> VNDetectRectanglesRequest {
    let request = VNDetectRectanglesRequest()
    request.maximumObservations = 1
    request.minimumAspectRatio = 0.5
    request.maximumAspectRatio = 1.0
    request.minimumConfidence = 0.5
    request.quadratureTolerance = 20.0
    return request
  }

  func makeTextRecognitionRequest() -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.minimumTextHeight = 0.02
    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = false
    }
    return request
  }

  private func buildScanResult(fromRecognizedTexts texts: [String], options: PaymentCardScanOptions) -> PaymentCardScanResult {
    let allowedBrands = Set(options.restrictToBrands.map { $0.lowercased() })
    let candidatePANs = parser.findCandidatePANs(in: texts.joined(separator: " "))

    var bestPAN: String?
    var bestBrand: String?

    for pan in candidatePANs {
      guard pan.count >= 12, pan.count <= 19 else {
        continue
      }

      guard luhn.isValid(pan) else {
        continue
      }

      let brand = brandDetector.detectBrand(for: pan)
      if !allowedBrands.isEmpty && !allowedBrands.contains(brand) {
        continue
      }

      if bestPAN == nil || pan.count > (bestPAN?.count ?? 0) {
        bestPAN = pan
        bestBrand = brand
      }
    }

    guard let pan = bestPAN else {
      return PaymentCardScanResult(complete: false)
    }

    let expiry = options.scanExpiry ? parser.findFirstExpiry(in: texts) : nil
    let last4 = parser.extractLast4(from: pan)
    let brand = bestBrand ?? brandDetector.detectBrand(for: pan)
    let cardholderName = parser.findCardholderName(in: texts)
    let hasRestrictedUnknownBrand = !allowedBrands.isEmpty && !allowedBrands.contains(brand)

    return PaymentCardScanResult(
      pan: pan,
      last4: last4,
      expiryMonth: expiry?.month,
      expiryYear: expiry?.year,
      brand: brand,
      cardholderName: cardholderName,
      complete: !hasRestrictedUnknownBrand && last4 != nil
    )
  }

  private func detectCardRectangle(in image: VisionImageSource) -> VNRectangleObservation? {
    let request = makeRectangleRequest()

    do {
      try perform(requests: [request], on: image)
      return request.results?.first
    } catch {
      return nil
    }
  }

  private func recognizeText(in image: VisionImageSource, regionOfInterest: CGRect?) -> [String] {
    let request = makeTextRecognitionRequest()
    if let regionOfInterest {
      request.regionOfInterest = regionOfInterest
    }

    do {
      try perform(requests: [request], on: image)
      let observations = request.results ?? []
      return observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }
    } catch {
      return []
    }
  }

  private func perform(requests: [VNRequest], on image: VisionImageSource) throws {
    switch image {
    case .cgImage(let cgImage, let orientation):
      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
      try handler.perform(requests)
    case .ciImage(let ciImage, let orientation):
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
      try handler.perform(requests)
    #if canImport(CoreVideo)
    case .pixelBuffer(let pixelBuffer, let orientation):
      let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
      try handler.perform(requests)
    #endif
    }
  }

  private func makeVisionImage(from frame: Any) -> VisionImageSource? {
    #if canImport(UIKit)
    if let image = frame as? UIImage, let cgImage = image.cgImage {
      return .cgImage(cgImage, orientation: cgImagePropertyOrientation(from: image.imageOrientation))
    }
    #endif

    #if canImport(CoreImage)
    if let ciImage = frame as? CIImage {
      return .ciImage(ciImage, orientation: .up)
    }
    #endif

    if CFGetTypeID(frame as CFTypeRef) == CGImage.typeID {
      let cgImage = unsafeBitCast(frame, to: CGImage.self)
      return .cgImage(cgImage, orientation: .up)
    }

    #if canImport(CoreVideo)
    if CFGetTypeID(frame as CFTypeRef) == CVPixelBufferGetTypeID() {
      let pixelBuffer = unsafeBitCast(frame, to: CVPixelBuffer.self)
      return .pixelBuffer(pixelBuffer, orientation: .up)
    }
    #endif

    return nil
  }

  fileprivate func loadImage(from imageUri: String) -> VisionImageSource? {
    let trimmed = imageUri.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }

    let filePath: String
    if let url = URL(string: trimmed), url.isFileURL {
      filePath = url.path
    } else if trimmed.hasPrefix("file://") {
      filePath = String(trimmed.dropFirst("file://".count))
    } else {
      filePath = trimmed
    }

    #if canImport(UIKit)
    if let image = UIImage(contentsOfFile: filePath), let cgImage = image.cgImage {
      return .cgImage(cgImage, orientation: cgImagePropertyOrientation(from: image.imageOrientation))
    }
    #endif

    #if canImport(CoreImage)
    if let ciImage = CIImage(contentsOf: URL(fileURLWithPath: filePath)) {
      return .ciImage(ciImage, orientation: .up)
    }
    #endif

    return nil
  }

  #if canImport(UIKit)
  private func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up:
      return .up
    case .down:
      return .down
    case .left:
      return .left
    case .right:
      return .right
    case .upMirrored:
      return .upMirrored
    case .downMirrored:
      return .downMirrored
    case .leftMirrored:
      return .leftMirrored
    case .rightMirrored:
      return .rightMirrored
    @unknown default:
      return .up
    }
  }
  #endif
}

fileprivate enum VisionImageSource {
  case cgImage(CGImage, orientation: CGImagePropertyOrientation)
  case ciImage(CIImage, orientation: CGImagePropertyOrientation)
  #if canImport(CoreVideo)
  case pixelBuffer(CVPixelBuffer, orientation: CGImagePropertyOrientation)
  #endif
}

@objcMembers
public final class PaymentCardScannerPluginBridge: NSObject {
  private let plugin = PaymentCardScannerPlugin()

  public override init() {
    super.init()
  }

  @objc
  public func isSupported() -> Bool {
    return plugin.isSupported()
  }

  @objc(scanCard:restrictToBrands:)
  public func scanCard(_ scanExpiry: NSNumber?, restrictToBrands: NSArray?) -> NSDictionary {
    let options = PaymentCardScanOptions(
      scanExpiry: scanExpiry?.boolValue ?? true,
      restrictToBrands: (restrictToBrands as? [String]) ?? []
    )

    let result = plugin.scanCard(options: options)
    return result.toDictionary() as NSDictionary
  }

  @objc(scanPixelBuffer:orientation:scanExpiry:restrictToBrands:)
  public func scanPixelBuffer(
    _ pixelBuffer: CVPixelBuffer,
    orientation: NSNumber?,
    scanExpiry: NSNumber?,
    restrictToBrands: NSArray?
  ) -> NSDictionary? {
    let options = PaymentCardScanOptions(
      scanExpiry: scanExpiry?.boolValue ?? true,
      restrictToBrands: (restrictToBrands as? [String]) ?? []
    )

    let orientationRaw = orientation?.intValue ?? UIImage.Orientation.up.rawValue
    let uiOrientation = UIImage.Orientation(rawValue: orientationRaw) ?? .up
    let image = VisionImageSource.pixelBuffer(
      pixelBuffer,
      orientation: bridgeCGImagePropertyOrientation(from: uiOrientation)
    )
    let result = plugin.scanPaymentCard(image: image, options: options)
    guard result.pan != nil || result.complete else {
      return nil
    }
    return result.toDictionary() as NSDictionary
  }

  #if canImport(UIKit)
  private func bridgeCGImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up:
      return .up
    case .down:
      return .down
    case .left:
      return .left
    case .right:
      return .right
    case .upMirrored:
      return .upMirrored
    case .downMirrored:
      return .downMirrored
    case .leftMirrored:
      return .leftMirrored
    case .rightMirrored:
      return .rightMirrored
    @unknown default:
      return .up
    }
  }
  #endif

  @objc(scanCardImage:scanExpiry:restrictToBrands:)
  public func scanCardImage(
    _ imageUri: NSString,
    scanExpiry: NSNumber?,
    restrictToBrands: NSArray?
  ) -> NSDictionary {
    let options = PaymentCardScanOptions(
      scanExpiry: scanExpiry?.boolValue ?? true,
      restrictToBrands: (restrictToBrands as? [String]) ?? []
    )

    guard let image = plugin.loadImage(from: imageUri as String) else {
      return PaymentCardScanResult(complete: false).toDictionary() as NSDictionary
    }

    let result = plugin.scanPaymentCard(image: image, options: options)
    return result.toDictionary() as NSDictionary
  }
}
