#import "VisionCameraPaymentCardScanner.h"
#import "VisionCameraPaymentCardScanner-Swift.h"

#import <Vision/Vision.h>

@implementation VisionCameraPaymentCardScanner

RCT_EXPORT_MODULE()

- (void)isSupported:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  PaymentCardScannerPluginBridge *bridge = [PaymentCardScannerPluginBridge new];
  resolve(@([bridge isSupported]));
}

- (void)scanCard:(JS::NativeVisionCameraPaymentCardScanner::NativeScanCardOptions &)options
         resolve:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject
{
  PaymentCardScannerPluginBridge *bridge = [PaymentCardScannerPluginBridge new];

  NSNumber *scanExpiry = nil;
  if (options.scanExpiry().has_value()) {
    scanExpiry = @(options.scanExpiry().value());
  }

  NSArray<NSString *> *restrictToBrands = nil;
  if (options.restrictToBrands().has_value()) {
    NSMutableArray<NSString *> *brands = [NSMutableArray new];
    auto lazyBrands = options.restrictToBrands().value();
    for (size_t index = 0; index < lazyBrands.size(); index++) {
      NSString *brand = lazyBrands[index];
      if (brand != nil) {
        [brands addObject:brand];
      }
    }
    restrictToBrands = brands;
  }

  NSDictionary *result = [bridge scanCard:scanExpiry restrictToBrands:restrictToBrands];
  resolve(result);
}

- (void)scanCardImage:(JS::NativeVisionCameraPaymentCardScanner::NativeCardImageScanOptions &)options
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject
{
  PaymentCardScannerPluginBridge *bridge = [PaymentCardScannerPluginBridge new];

  NSString *imageUri = options.imageUri();
  if (imageUri == nil || imageUri.length == 0) {
    resolve(@{ @"complete": @(NO) });
    return;
  }

  NSNumber *scanExpiry = nil;
  if (options.scanExpiry().has_value()) {
    scanExpiry = @(options.scanExpiry().value());
  }

  NSArray<NSString *> *restrictToBrands = nil;
  if (options.restrictToBrands().has_value()) {
    NSMutableArray<NSString *> *brands = [NSMutableArray new];
    auto lazyBrands = options.restrictToBrands().value();
    for (size_t index = 0; index < lazyBrands.size(); index++) {
      NSString *brand = lazyBrands[index];
      if (brand != nil) {
        [brands addObject:brand];
      }
    }
    restrictToBrands = brands;
  }

  NSDictionary *result = [bridge scanCardImage:imageUri
                                    scanExpiry:scanExpiry
                              restrictToBrands:restrictToBrands];
  resolve(result);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeVisionCameraPaymentCardScannerSpecJSI>(params);
}


@end
