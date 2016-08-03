//
//  Importer.swift
//  Potatso
//
//  Created by LEI on 4/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import PotatsoLibrary

struct Importer {
    
    weak var viewController: UIViewController?
    
    init(vc: UIViewController) {
        self.viewController = vc
    }
    
    func importConfigFromUrl() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Import Config From URL".localized(), message: nil, preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Input URL".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default, handler: { (action) in
            if let input = urlTextField?.text {
                self.onImportInput(input)
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
        viewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func importConfigFromQRCode() {
        let vc = QRCodeScannerVC()
        vc.resultBlock = { [weak vc] result in
            vc?.navigationController?.popViewControllerAnimated(true)
            self.onImportInput(result)
        }
        vc.errorBlock = { [weak vc] error in
            vc?.navigationController?.popViewControllerAnimated(true)
            self.viewController?.showTextHUD("\(error)", dismissAfterDelay: 1.5)
        }
        viewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onImportInput(result: String) {
        if Proxy.uriIsShadowsocks(result) {
            importSS(result)
        }else {
            importConfig(result, isURL: true)
        }
    }
    
    func importSS(source: String) {
        do {
            let defaultName = "___scanresult"
            let proxy = try Proxy(dictionary: ["name": defaultName, "uri": source], inRealm: defaultRealm)
            var urlTextField: UITextField?
            let alert = UIAlertController(title: "Add a new proxy".localized(), message: "Please set name for the new proxy".localized(), preferredStyle: .Alert)
            alert.addTextFieldWithConfigurationHandler { (textField) in
                textField.placeholder = "Input name".localized()
                if proxy.name != defaultName {
                    textField.text = proxy.name
                }
                urlTextField = textField
            }
            alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default){ (action) in
                guard let text = urlTextField?.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) else {
                    self.onConfigSaveCallback(false, error: "Name can't be empty".localized())
                    return
                }
                proxy.name = text
                do {
                    try proxy.validate(inRealm: defaultRealm)
                    try defaultRealm.write {
                        defaultRealm.add(proxy)
                    }
                    self.onConfigSaveCallback(true, error: nil)
                }catch {
                    self.onConfigSaveCallback(false, error: error)
                }
                })
            alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel) { action in
                })
            viewController?.presentViewController(alert, animated: true, completion: nil)
        }catch {
            self.onConfigSaveCallback(false, error: error)
        }
        if let vc = viewController {
            Alert.show(vc, message: "Fail to parse proxy config".localized())
        }
    }
    
    func importConfig(source: String, isURL: Bool) {
        viewController?.showProgreeHUD("Importing Config...".localized())
        Async.background(after: 1) {
            let config = Config()
            do {
                if isURL {
                    if let url = NSURL(string: source) {
                        try config.setup(url: url)
                    }
                }else {
                    try config.setup(string: source)
                }
                try config.save()
                self.onConfigSaveCallback(true, error: nil)
            }catch {
                self.onConfigSaveCallback(false, error: error)
            }
        }
    }
    
    func onConfigSaveCallback(success: Bool, error: ErrorType?) {
        Async.main(after: 0.5) {
            self.viewController?.hideHUD()
            if !success {
                var errorDesc = ""
                if let error = error {
                    errorDesc = "(\(error))"
                }
                if let vc = self.viewController {
                    Alert.show(vc, message: "\("Fail to save config.".localized()) \(errorDesc)")
                }
            }else {
                self.viewController?.showTextHUD("Import Success".localized(), dismissAfterDelay: 1.5)
            }
        }
    }

}