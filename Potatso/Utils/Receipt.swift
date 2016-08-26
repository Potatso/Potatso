//
//  Receipt.swift
//  Potatso
//
//  Created by LEI on 7/5/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework

class Receipt: NSObject, SKRequestDelegate {

    static let shared = Receipt()

    private override init() {}

    func validate() {
        if AppEnv.isTestFlight {
            NSLog("isTestFlight")
            if !validateKeychainAppStore() {
                NSLog("validateKeychainAppStore fail")
                failAndTerminate()
            }
        }
        if AppEnv.isAppStore {
            NSLog("isAppStore")
            if isStoreReceiptValidate() {
                NSLog("isStoreReceiptValidate true")
                markKeychainAppStore()
            } else {
                NSLog("isStoreReceiptValidate false")
                failAndTerminate()
            }
        }
    }

    private func markKeychainAppStore() {
        keychain["appstore"] = "true"
    }

    private func validateKeychainAppStore() -> Bool {
        NSLog("validateKeychainAppStore")
        if let value = keychain["appstore"] {
            NSLog("keychain value: \(value)")
            return value == "true"
        }
        return false
    }

    private func isStoreReceiptValidate() -> Bool {
        NSLog("appStoreReceiptURL: \(NSBundle.mainBundle().appStoreReceiptURL)")
        guard let receiptPath = NSBundle.mainBundle().appStoreReceiptURL?.path where NSFileManager.defaultManager().fileExistsAtPath(receiptPath) else {
            NSLog("isStoreReceiptValidate can't find appStoreReceiptURL")
            return false
        }
        return ReceiptUtils.verifyReceiptAtPath(receiptPath)
    }

    private func requestNewReceipt() {
        let req = SKReceiptRefreshRequest()
        req.delegate = self
        req.start()
    }

    private func validateReceipt(path: String, tryAgain: Bool) {
        let valid = ReceiptUtils.verifyReceiptAtPath(path)
        logEvent(.ReceiptValidationResult, attributes: ["valid": valid ? "true" : "false"])
        if !valid {
            if tryAgain {
                requestNewReceipt()
            }else {
                failAndTerminate()
            }
        }
    }

    private func failAndTerminate() {
//        dispatch_async(dispatch_get_main_queue()) { 
//            guard let vc = UIApplication.sharedApplication().keyWindow?.rootViewController else {
//                return
//            }
//            Alert.show(vc, title: "Receipt Validation Error".localized(), message: "The app is only made for App Store users. Please try again.".localized(), confirmMessage: "CANCEL".localized(), confirmCallback: {
//                logEvent(.ReceiptValidationCancel, attributes: nil)
//                self.terminate()
//            }, cancelMessage: "BUY".localized()) {
//                logEvent(.ReceiptValidationBuy, attributes: nil)
//                Appirater.rateApp()
//                self.terminate()
//            }
//
//        }
    }

    private func terminate() {
        exit(173)
    }

    // MARK: - SKRequestDelegate

    @objc func requestDidFinish(request: SKRequest) {
        guard let receiptPath = NSBundle.mainBundle().appStoreReceiptURL?.path where NSFileManager.defaultManager().fileExistsAtPath(receiptPath) else {
            failAndTerminate()
            return
        }
        validateReceipt(receiptPath, tryAgain: false)
    }

    @objc func request(request: SKRequest, didFailWithError error: NSError) {
        failAndTerminate()
    }

}