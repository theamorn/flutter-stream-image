import UIKit
import Flutter
import VideoToolbox

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
        
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "com.benamorn.liveness",
                binaryMessenger: controller.binaryMessenger)
            
            channel.setMethodCallHandler({ [weak self] (
                call: FlutterMethodCall,
                result: @escaping FlutterResult) -> Void in
                switch call.method {
                case "checkLiveness":
                    if let data = call.arguments as? [String: Any] {
                        self?.checkLiveness(data: data)
                    } else {
                        result(FlutterMethodNotImplemented)
                    }
                default:
                    result(FlutterMethodNotImplemented)
                }
            })
        }
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func checkLiveness(data: [String: Any]) {
        guard let imageWidth = data["width"] as? Int, let imageHeight = data["height"] as? Int else { return }
        
       // Initialize Liveness over here
        
        guard let flutterData = data["platforms"] as? FlutterStandardTypedData,
              let bytesPerRow = data["bytesPerRow"] as? Int else {
            return
        }
        
        guard let image = createUIImageFromRawData(data: flutterData.data,
                                                   imageWidth: imageWidth,
                                                   imageHeight: imageHeight,
                                                   bytes: bytesPerRow) else {
            return
        }
        // Feed image into liveness
    }
   
    // Group of util to convert image
    private func bytesToPixelBuffer(width: Int, height: Int, baseAddress: UnsafeMutableRawPointer, bytesPerRow: Int) -> CVBuffer? {
        var dstPixelBuffer: CVBuffer?
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, baseAddress, bytesPerRow,
                                     nil, nil, nil, &dstPixelBuffer)
        return dstPixelBuffer ?? nil
    }
    
    private func createImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        return cgImage
    }
    
    private func createUIImageFromRawData(data: Data, imageWidth: Int, imageHeight: Int, bytes: Int) -> UIImage? {
        data.withUnsafeBytes { rawBufferPointer in
            let rawPtr = rawBufferPointer.baseAddress!
            let address = UnsafeMutableRawPointer(mutating:rawPtr)
            guard let pxBuffer = bytesToPixelBuffer(width: imageWidth, height: imageHeight, baseAddress: address, bytesPerRow: bytes), let copyImage = pxBuffer.copy() , let cgiImage = createImage(from: pxBuffer) else {
                return nil
            }
            
            return UIImage(cgImage: cgiImage)
        }
    }
    
}
