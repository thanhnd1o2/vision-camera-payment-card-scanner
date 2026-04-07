#import <Foundation/Foundation.h>

#if __has_include(<VisionCamera/FrameProcessorPlugin.h>)
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/Frame.h>
#elif __has_include("FrameProcessorPlugin.h")
#import "FrameProcessorPlugin.h"
#import "Frame.h"
#endif

#if __has_include("VisionCameraPaymentCardScanner-Swift.h")
#import "VisionCameraPaymentCardScanner-Swift.h"
#endif

#if __has_include(<VisionCamera/FrameProcessorPlugin.h>) || __has_include("FrameProcessorPlugin.h")
@interface PaymentCardScannerFrameProcessorPlugin : FrameProcessorPlugin
@end

@implementation PaymentCardScannerFrameProcessorPlugin {
  PaymentCardScannerPluginBridge* _bridge;
}

- (instancetype _Nonnull)initWithProxy:(VisionCameraProxyHolder* _Nonnull)proxy
                           withOptions:(NSDictionary* _Nullable)options {
  self = [super initWithProxy:proxy withOptions:options];
  if (self != nil) {
    _bridge = [PaymentCardScannerPluginBridge new];
    (void)options;
  }
  return self;
}

- (id _Nullable)callback:(Frame* _Nonnull)frame withArguments:(NSDictionary* _Nullable)arguments {
  NSNumber* scanExpiry = nil;
  NSArray* restrictToBrands = nil;

  if ([arguments isKindOfClass:[NSDictionary class]]) {
    id rawScanExpiry = arguments[@"scanExpiry"];
    if ([rawScanExpiry isKindOfClass:[NSNumber class]]) {
      scanExpiry = (NSNumber*)rawScanExpiry;
    }

    id rawRestrictToBrands = arguments[@"restrictToBrands"];
    if ([rawRestrictToBrands isKindOfClass:[NSArray class]]) {
      restrictToBrands = (NSArray*)rawRestrictToBrands;
    }
  }

  CMSampleBufferRef sampleBuffer = frame.buffer;
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    return nil;
  }

  return [_bridge scanPixelBuffer:pixelBuffer
                      orientation:@(frame.orientation)
                       scanExpiry:scanExpiry
                 restrictToBrands:restrictToBrands];
}

VISION_EXPORT_FRAME_PROCESSOR(PaymentCardScannerFrameProcessorPlugin, scanPaymentCard)

@end
#endif
