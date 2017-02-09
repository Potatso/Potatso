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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        generateForm()
    }

    func generateForm() {
        form.delegate = nil
        form.removeAll()
        form +++ generateManualSection()
        form +++ generateSyncSection()
        form +++ generateRateSection()
        form +++ generateAboutSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateManualSection() -> Section {
        let section = Section()
        section
            <<< ActionRow {
                $0.title = "User Manual".localized()
            }.onCellSelection({ [unowned self] (cell, row) in
                self.showUserManual()
            })
            <<< ActionRow {
                $0.title = "Feedback".localized()
            }.onCellSelection({ (cell, row) in
                FeedbackManager.shared.showFeedback()
            })
        return section
    }

    func generateSyncSection() -> Section {
        let section = Section()
        section
            <<< ActionRow() {
                $0.title = "Sync".localized()
                $0.value = SyncManager.shared.currentSyncServiceType.rawValue
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                SyncManager.shared.showSyncVC(inVC: self)
            })
            <<< ActionRow() {
                $0.title = "Import From URL".localized()
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                let importer = Importer(vc: self)
                importer.importConfigFromUrl()
            })
            <<< ActionRow() {
                $0.title = "Import From QRCode".localized()
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                let importer = Importer(vc: self)
                importer.importConfigFromQRCode()
            })
        return section
    }

    func generateRateSection() -> Section {
        let section = Section()
        section
            <<< ActionRow() {
                $0.title = "Rate on App Store".localized()
            }.onCellSelection({ (cell, row) -> () in
                Appirater.rateApp()
            })
            <<< ActionRow() {
                $0.title = "Share with friends".localized()
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                self.shareWithFriends()
            })
        return section
    }

    func generateAboutSection() -> Section {
        let section = Section()
        section
            <<< ActionRow() {
                $0.title = "Follow on Twitter".localized()
                $0.value = "@PotatsoApp"
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                self.followTwitter()
            })
            <<< ActionRow() {
                $0.title = "Follow on Weibo".localized()
                $0.value = "@Potatso"
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                self.followWeibo()
            })
            <<< ActionRow() {
                $0.title = "Join Telegram Group".localized()
                $0.value = "@Potatso"
            }.onCellSelection({ [unowned self] (cell, row) -> () in
                self.joinTelegramGroup()
            })
            <<< LabelRow() {
                $0.title = "Version".localized()
                $0.value = AppEnv.fullVersion
            }
        return section
    }

    func showUserManual() {
        let url = "https://manual.potatso.com/"
        let vc = BaseSafariViewController(url: URL(string: url)!, entersReaderIfAvailable: false)
        vc.delegate = self
        present(vc, animated: true, completion: nil)
    }

    func followTwitter() {
        UIApplication.shared.openURL(URL(string: "https://twitter.com/intent/user?screen_name=potatsoapp")!)
    }

    func followWeibo() {
        UIApplication.shared.openURL(URL(string: "http://weibo.com/potatso")!)
    }

    func joinTelegramGroup() {
        UIApplication.shared.openURL(URL(string: "https://telegram.me/joinchat/BT0c4z49OGNZXwl9VsO0uQ")!)
    }

    func shareWithFriends() {
        var shareItems: [AnyObject] = []
        shareItems.append("Potatso [https://itunes.apple.com/us/app/id1070901416]" as AnyObject)
        shareItems.append(UIImage(named: "AppIcon60x60")!)
        let shareVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        self.present(shareVC, animated: true, completion: nil)
    }

    @objc func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
