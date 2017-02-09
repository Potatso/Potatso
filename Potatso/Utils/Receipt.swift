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

    fileprivate override init() {}

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

    fileprivate func markKeychainAppStore() {
        keychain["appstore"] = "true"
    }

    fileprivate func validateKeychainAppStore() -> Bool {
        NSLog("validateKeychainAppStore")
        if let value = keychain["appstore"] {
            NSLog("keychain value: \(value)")
            return value == "true"
        }
        return false
    }

    fileprivate func isStoreReceiptValidate() -> Bool {
        NSLog("appStoreReceiptURL: \(Bundle.main.appStoreReceiptURL)")
        guard let receiptPath = Bundle.main.appStoreReceiptURL?.path, FileManager.default.fileExists(atPath: receiptPath) else {
            NSLog("isStoreReceiptValidate can't find appStoreReceiptURL")
            return false
        }
        return ReceiptUtils.verifyReceipt(atPath: receiptPath)
    }

    fileprivate func requestNewReceipt() {
        let req = SKReceiptRefreshRequest()
        req.delegate = self
        req.start()
    }

    fileprivate func validateReceipt(_ path: String, tryAgain: Bool) {
        let valid = ReceiptUtils.verifyReceipt(atPath: path)
        logEvent(.ReceiptValidationResult, attributes: ["valid": valid ? "true" as AnyObject: "false" as AnyObject])
        if !valid {
            if tryAgain {
                requestNewReceipt()
            }else {
                failAndTerminate()
            }
        }
    }

    fileprivate func failAndTerminate() {
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

    fileprivate func terminate() {
        exit(173)
    }

    // MARK: - SKRequestDelegate

    @objc func requestDidFinish(_ request: SKRequest) {
        guard let receiptPath = Bundle.main.appStoreReceiptURL?.path, FileManager.default.fileExists(atPath: receiptPath) else {
            failAndTerminate()
            return
        }
        validateReceipt(receiptPath, tryAgain: false)
    }

    @objc func request(_ request: SKRequest, didFailWithError error: NSError) {
        failAndTerminate()
    }

}
