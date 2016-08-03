//
//  QRCodeScannerVC.h
//  Potatso
//
//  Created by LEI on 7/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^CDZQRScanResultBlock)(NSString *scanResult);
typedef void (^CDZQRScanErrorBlock)(NSError *error);
typedef void (^CDZQRScanCancelBlock)();

extern NSString * const CDZQRScanningErrorDomain;

typedef NS_ENUM(NSInteger, CDZQRScanningViewControllerErrorCode) {
    CDZQRScanningViewControllerErrorUnavailableMetadataObjectType = 1,
};

/**
 *  Easy barcode scanning view controller for iOS 7.
 */

@interface QRCodeScannerVC : UIViewController

/**
 *  Returns a scanning view controller configured to accept the given metadata object types.
 *
 *  @param metadataObjectTypes An array of `AVMetadataMachineReadableCodeObject`s
 *
 *  @return Scanning view controller configured to accept the given metadata object types
 */
- (instancetype)initWithMetadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 *  Returns a scanning view controller configured to accept QR codes
 *
 *  @note This is equivalent to calling `initWithMetadataObjectTypes:@[ AVMetadataObjectTypeQRCode ]`
 *
 *  @return Scanning view controller configured to accept QR codes
 */
- (instancetype)init;

// Your blocks will be called on the main queue.
@property (nonatomic, copy) CDZQRScanResultBlock resultBlock;
@property (nonatomic, copy) CDZQRScanErrorBlock errorBlock;
@property (nonatomic, copy) CDZQRScanCancelBlock cancelBlock;

/**
 *  An array of `AVMetadataMachineReadableCodeObject`s
 */
@property (nonatomic, strong, readonly) NSArray *metadataObjectTypes;

@end