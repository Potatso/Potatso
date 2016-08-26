//
//  QRCodeScannerVC.m
//  Potatso
//
//  Created by LEI on 7/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "QRCodeScannerVC.h"
#import <AVFoundation/AVFoundation.h>
#import "HMScanner.h"
#import "Potatso-Swift.h"

#ifndef CDZWeakSelf
#define CDZWeakSelf __weak __typeof__((__typeof__(self))self)
#endif

#ifndef CDZStrongSelf
#define CDZStrongSelf __typeof__(self)
#endif

static AVCaptureVideoOrientation CDZVideoOrientationFromInterfaceOrientation(UIInterfaceOrientation interfaceOrientation)
{
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

static const float CDZQRScanningTorchLevel = 0.25;
static const NSTimeInterval CDZQRScanningTorchActivationDelay = 0.25;

NSString * const CDZQRScanningErrorDomain = @"com.cdzombak.qrscanningviewcontroller";

@interface QRCodeScannerVC () <AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) AVCaptureSession *avSession;
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, copy) NSString *lastCapturedString;

@property (nonatomic, strong, readwrite) NSArray *metadataObjectTypes;

@end

@implementation QRCodeScannerVC

- (instancetype)initWithMetadataObjectTypes:(NSArray *)metadataObjectTypes {
    self = [super init];
    if (!self) return nil;
    self.metadataObjectTypes = metadataObjectTypes;
    self.title = NSLocalizedString(@"qrcode.title", nil);
    return self;
}

- (instancetype)init {
    return [self initWithMetadataObjectTypes:@[ AVMetadataObjectTypeQRCode ]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"qrcode.album", nil) style:UIBarButtonItemStylePlain target:self action:@selector(clickAlbumButton)];

    UILongPressGestureRecognizer *torchGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTorchRecognizerTap:)];
    torchGestureRecognizer.minimumPressDuration = CDZQRScanningTorchActivationDelay;
    [self.view addGestureRecognizer:torchGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.lastCapturedString = nil;

    if (self.cancelBlock && !self.errorBlock) {
        CDZWeakSelf wSelf = self;
        self.errorBlock = ^(NSError *error) {
            CDZStrongSelf sSelf = wSelf;
            if (sSelf.cancelBlock) {
                [sSelf.avSession stopRunning];
                sSelf.cancelBlock();
            }
        };
    }

    self.avSession = [[AVCaptureSession alloc] init];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([self.captureDevice isLowLightBoostSupported] && [self.captureDevice lockForConfiguration:nil]) {
            self.captureDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
            [self.captureDevice unlockForConfiguration];
        }

        [self.avSession beginConfiguration];

        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&error];
        if (input) {
            [self.avSession addInput:input];
        } else {
            NSLog(@"QRScanningViewController: Error getting input device: %@", error);
            [self.avSession commitConfiguration];
            if (self.errorBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.avSession stopRunning];
                    self.errorBlock(error);
                });
            }
            return;
        }

        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
        [self.avSession addOutput:output];
        for (NSString *type in self.metadataObjectTypes) {
            if (![output.availableMetadataObjectTypes containsObject:type]) {
                if (self.errorBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.avSession stopRunning];
                        self.errorBlock([NSError errorWithDomain:CDZQRScanningErrorDomain code:CDZQRScanningViewControllerErrorUnavailableMetadataObjectType userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Unable to scan object of type %@", type]}]);
                    });
                }
                return;
            }
        }

        output.metadataObjectTypes = self.metadataObjectTypes;
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];

        [self.avSession commitConfiguration];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.previewLayer.connection.isVideoOrientationSupported) {
                self.previewLayer.connection.videoOrientation = CDZVideoOrientationFromInterfaceOrientation([[UIApplication sharedApplication] statusBarOrientation]);
            }

            [self.avSession startRunning];
        });
    });

    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.avSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.view.bounds;
    if (self.previewLayer.connection.isVideoOrientationSupported) {
        self.previewLayer.connection.videoOrientation = CDZVideoOrientationFromInterfaceOrientation([[UIApplication sharedApplication] statusBarOrientation]);
    }
    [self.view.layer addSublayer:self.previewLayer];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    self.avSession = nil;
    self.captureDevice = nil;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

    if (self.previewLayer.connection.isVideoOrientationSupported) {
        self.previewLayer.connection.videoOrientation = CDZVideoOrientationFromInterfaceOrientation(toInterfaceOrientation);
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect layerRect = self.view.bounds;
    self.previewLayer.bounds = layerRect;
    self.previewLayer.position = CGPointMake(CGRectGetMidX(layerRect), CGRectGetMidY(layerRect));
}

#pragma mark - UI Actions

- (void)cancelItemSelected:(id)sender {
    [self.avSession stopRunning];
    if (self.cancelBlock) self.cancelBlock();
}

- (void)handleTorchRecognizerTap:(UIGestureRecognizer *)sender {
    switch(sender.state) {
        case UIGestureRecognizerStateBegan:
            [self turnTorchOn];
            break;
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStatePossible:
            // no-op
            break;
        case UIGestureRecognizerStateRecognized: // also UIGestureRecognizerStateEnded
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
            [self turnTorchOff];
            break;
    }
}

#pragma mark - Torch

- (void)turnTorchOn {
    if (self.captureDevice.hasTorch && self.captureDevice.torchAvailable && [self.captureDevice isTorchModeSupported:AVCaptureTorchModeOn] && [self.captureDevice lockForConfiguration:nil]) {
        [self.captureDevice setTorchModeOnWithLevel:CDZQRScanningTorchLevel error:nil];
        [self.captureDevice unlockForConfiguration];
    }
}

- (void)turnTorchOff {
    if (self.captureDevice.hasTorch && [self.captureDevice isTorchModeSupported:AVCaptureTorchModeOff] && [self.captureDevice lockForConfiguration:nil]) {
        self.captureDevice.torchMode = AVCaptureTorchModeOff;
        [self.captureDevice unlockForConfiguration];
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSString *result;

    for (AVMetadataObject *metadata in metadataObjects) {
        if ([self.metadataObjectTypes containsObject:metadata.type]) {
            result = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
            break;
        }
    }

    if (result && ![self.lastCapturedString isEqualToString:result]) {
        self.lastCapturedString = result;
        [self.avSession stopRunning];
        if (self.resultBlock) self.resultBlock(result);
    }
}


/// 点击相册按钮
- (void)clickAlbumButton {

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self showTextHUD:NSLocalizedString(@"qrcode.denied", nil) dismissAfterDelay:1.0f];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];

    picker.view.backgroundColor = [UIColor whiteColor];
    picker.delegate = self;

    [self showDetailViewController:picker sender:nil];
}


#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {

    // 扫描图像
    [HMScanner scaneImage:info[UIImagePickerControllerOriginalImage] completion:^(NSArray *values) {
        if (values.count > 0) {
            if (self.resultBlock) {
                self.resultBlock(values.firstObject);
            }
            CDZWeakSelf wSelf = self;
            [self dismissViewControllerAnimated:NO completion:^{
                [wSelf close];
            }];
        } else {
            [self showTextHUD:NSLocalizedString(@"qrcode.nocode", nil) dismissAfterDelay:1.0f];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

@end