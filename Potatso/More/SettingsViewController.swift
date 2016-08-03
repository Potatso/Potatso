//
//  MoreViewController.swift
//  Potatso
//
//  Created by LEI on 1/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Eureka
import Appirater
import ICSMainFramework
import MessageUI
import SafariServices
import PotatsoLibrary

enum FeedBackType: String, CustomStringConvertible {
    case Email = "Email"
    case Forum = "Forum"
    case None = ""
    
    var description: String {
        return rawValue.localized()
    }
}



class SettingsViewController: FormViewController, MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "More".localized()
        generateForm()
    }
    
    func generateForm() {
        form +++ Section()
            <<< LabelRow() {
                $0.title = "Feedback".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ [unowned self] (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    self.feedback()
                    })
        +++ Section()
            <<< LabelRow() {
                $0.title = "Import From URL".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    let importer = Importer(vc: self)
                    importer.importConfigFromUrl()
                })
            <<< LabelRow() {
                $0.title = "Import From QRCode".localized()
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    let importer = Importer(vc: self)
                    importer.importConfigFromQRCode()
                })
        +++ Section()
            <<< ButtonRow() {
                $0.title = "User Manual".localized()
                $0.presentationMode = PresentationMode.PresentModally(controllerProvider: ControllerProvider.Callback(builder: { [unowned self]() -> BaseSafariViewController in
                    let url = "http://manual.potatso.com/"
                    let vc = BaseSafariViewController(URL: NSURL(string: url)!, entersReaderIfAvailable: false)
                    vc.delegate = self
                    return vc
                }), completionCallback: { (vc) -> () in
                    
                })
            }
//        +++ Section()
//            <<< ActionSheetRow<LoggingLevel>() {
//                $0.title = "Logging"
//                $0.selectorTitle = "Logging"
//                $0.options = [.OFF, .DEBUG]
//                $0.value = LoggingLevel.currentLoggingLevel
//            }.cellUpdate({ (cell, row) -> () in
//                cell.accessoryType = .DisclosureIndicator
//            }).onChange({ [unowned self] (row) in
//                if let v = row.value {
//                    LoggingLevel.currentLoggingLevel = v
////                    self.showTextHUD("works after next restart", dismissAfterDelay: 1.0)
//                    self.showTextHUD("暂时不起作用", dismissAfterDelay: 1.0)
//                }
//            })
        +++ Section()
        <<< LabelRow() {
            $0.title = "Rate on App Store".localized()
        }.cellSetup({ (cell, row) -> () in
            cell.selectionStyle = .Default
            cell.accessoryType = .DisclosureIndicator
        }).onCellSelection({ (cell, row) -> () in
            cell.setSelected(false, animated: true)
            Appirater.rateApp()
        })
        <<< LabelRow() {
            $0.title = "Share with friends".localized()
        }.cellSetup({ (cell, row) -> () in
            cell.selectionStyle = .Default
            cell.accessoryType = .DisclosureIndicator
        }).onCellSelection({ [unowned self] (cell, row) -> () in
            cell.setSelected(false, animated: true)
            var shareItems: [AnyObject] = []
            shareItems.append("Potatso [https://itunes.apple.com/us/app/id1070901416]")
            shareItems.append(UIImage(named: "AppIcon60x60")!)
            let shareVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            self.presentViewController(shareVC, animated: true, completion: nil)
        })
        form +++ Section()
            <<< LabelRow() {
                $0.title = "Follow on Twitter".localized()
                $0.value = "@PotatsoApp"
            }.cellSetup({ (cell, row) -> () in
                cell.selectionStyle = .Default
                cell.accessoryType = .DisclosureIndicator
            }).onCellSelection({ (cell, row) -> () in
                cell.setSelected(false, animated: true)
                UIApplication.sharedApplication().openURL(NSURL(string: "https://twitter.com/intent/user?screen_name=potatsoapp")!)
            })
            <<< LabelRow() {
                $0.title = "Follow on Weibo".localized()
                $0.value = "@Potatso"
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    UIApplication.sharedApplication().openURL(NSURL(string: "http://weibo.com/potatso")!)
                })
            <<< LabelRow() {
                $0.title = "Telegram Channel".localized()
                $0.value = "@Potatso"
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    UIApplication.sharedApplication().openURL(NSURL(string: "https://telegram.me/potatso")!)
                })
            <<< LabelRow() {
                $0.title = "Website".localized()
                $0.value = "http://potatso.com"
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .Default
                    cell.accessoryType = .DisclosureIndicator
                }).onCellSelection({ (cell, row) -> () in
                    cell.setSelected(false, animated: true)
                    UIApplication.sharedApplication().openURL(NSURL(string: "http://potatso.com")!)
                })
            <<< LabelRow() {
                $0.title = "Version".localized()
                $0.value = AppEnv.fullVersion
            }

    }
    
    func feedback() {
        let options = [
            "gotoConversationAfterContactUs": "YES"
        ]
        let rulesets = Manager.sharedManager.defaultConfigGroup.ruleSets.map({ $0.name }).joinWithSeparator(", ")
        let defaultToProxy = Manager.sharedManager.defaultConfigGroup.defaultToProxy
        var tags: [String] = []
        if AppEnv.isTestFlight {
            tags.append("testflight")
        } else if AppEnv.isAppStore {
            tags.append("store")
        }
        HelpshiftSupport.setMetadataBlock { () -> [NSObject : AnyObject]! in
            return [
                "Full Version": AppEnv.fullVersion,
                "Default To Proxy": defaultToProxy ? "true": "false",
                "Rulesets": rulesets,
                HelpshiftSupportTagsKey: tags
            ]
        }
        HelpshiftSupport.showConversation(self, withOptions: options)
    }

    @objc func safariViewControllerDidFinish(controller: SFSafariViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
}