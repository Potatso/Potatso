//
//  ConifgGroupCell.swift
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Cartography
import PotatsoModel
import PotatsoLibrary

class ConfigGroupCell: UITableViewCell {
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        loadView()
        preservesSuperviewLayoutMargins = false
        layoutMargins = UIEdgeInsets.zero
        separatorInset = UIEdgeInsets.zero
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func config(_ group: ConfigurationGroup, hintColor: UIColor) {
        nameLabel.text = group.name
        proxyHintLabel.text = "Proxy".localized()
        proxyLabel.text = group.proxies.first?.name ?? "None".localized()
        ruleSetsHintLabel.text = "Rule Set".localized()
        let desc = group.ruleSets.map { (set) -> String in
            return set.name
        }.joined(separator: ", ")
        ruleSetsLabel.text = group.ruleSets.count > 0 ? "\(desc)" : "None".localized()
        leftColorHintView.backgroundColor = hintColor
        statusLabel.isHidden = true
        if group.isDefault && Manager.sharedManager.vpnStatus == .on {
            statusLabel.isHidden = false
        }
    }
    
    func loadView() {
        selectionStyle = .none
        backgroundColor = UIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        contentView.addSubview(backgroundWrapper)
        backgroundWrapper.addSubview(leftColorHintView)
        backgroundWrapper.addSubview(statusLabel)
        backgroundWrapper.addSubview(nameLabel)
        backgroundWrapper.addSubview(proxyHintLabel)
        backgroundWrapper.addSubview(proxyLabel)
        backgroundWrapper.addSubview(ruleSetsHintLabel)
        backgroundWrapper.addSubview(ruleSetsLabel)
        setupLayout()
    }
    
    func setupLayout() {
        constrain(backgroundWrapper, contentView) { backgroundWrapper, contentView in
            backgroundWrapper.edges == contentView.edges
        }
        constrain(leftColorHintView, backgroundWrapper) { leftColorHintView, backgroundWrapper in
            leftColorHintView.leading == backgroundWrapper.leading
            leftColorHintView.top == backgroundWrapper.top
            leftColorHintView.bottom == backgroundWrapper.bottom
            leftColorHintView.width == 3
        }
        constrain(nameLabel, statusLabel, backgroundWrapper) { nameLabel, statusLabel, backgroundWrapper in
            statusLabel.centerY == nameLabel.centerY
            statusLabel.trailing == backgroundWrapper.trailing - 15
            statusLabel.width == 80
            statusLabel.height == 20
        }
        constrain(nameLabel, proxyHintLabel, proxyLabel, backgroundWrapper) { nameLabel, proxyHintLabel, proxyLabel, backgroundWrapper in
            nameLabel.leading == backgroundWrapper.leading + 20
            nameLabel.top == backgroundWrapper.top + 15
            nameLabel.width <= backgroundWrapper.width - 120
            
            proxyHintLabel.leading == nameLabel.leading
            proxyHintLabel.top == nameLabel.bottom + 15
            proxyHintLabel.width <= backgroundWrapper.width/2 - 40
            
            proxyLabel.leading == nameLabel.leading
            proxyLabel.top == proxyHintLabel.bottom + 3
            proxyLabel.width <= backgroundWrapper.width/2 - 40
        }
        constrain(proxyHintLabel, ruleSetsHintLabel, backgroundWrapper) { proxyHintLabel, ruleSetsHintLabel, backgroundWrapper in
            ruleSetsHintLabel.leading == backgroundWrapper.centerX
            ruleSetsHintLabel.top == proxyHintLabel.top
            ruleSetsHintLabel.width == proxyHintLabel.width
        }
        
        constrain(proxyLabel, ruleSetsLabel, backgroundWrapper) { proxyLabel, ruleSetsLabel, backgroundWrapper in
            ruleSetsLabel.leading == backgroundWrapper.centerX
            ruleSetsLabel.top == proxyLabel.top
            ruleSetsLabel.width == proxyLabel.width
        }
        
    }
    
    lazy var nameLabel: UILabel = {
        let v = UILabel()
        v.textColor = Color.TextPrimary
        v.font = UIFont.boldSystemFont(ofSize: 18)
        v.adjustsFontSizeToFitWidth = true
        v.minimumScaleFactor = 0.8
        return v
    }()
    
    lazy var proxyHintLabel: UILabel = {
        let v = UILabel()
        v.textColor = Color.TextHint
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()
    
    lazy var proxyLabel: UILabel = {
        let v = UILabel()
        v.textColor = Color.TextSecond
        v.font = UIFont.systemFont(ofSize: 15)
        v.adjustsFontSizeToFitWidth = true
        v.minimumScaleFactor = 0.8
        return v
    }()
    
    lazy var ruleSetsHintLabel: UILabel = {
        let v = UILabel()
        v.textColor = Color.TextHint
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()
    
    lazy var ruleSetsLabel: UILabel = {
        let v = UILabel()
        v.textColor = Color.TextSecond
        v.font = UIFont.systemFont(ofSize: 15)
        v.adjustsFontSizeToFitWidth = true
        v.minimumScaleFactor = 0.8
        return v
    }()
    
    lazy var statusLabel: UILabel = {
        let v = UILabel()
        v.text = "Connected".localized()
        v.font = UIFont.systemFont(ofSize: 10)
        v.textColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = true
        v.backgroundColor = "1ABC9C".color
        v.textAlignment = .center
        v.adjustsFontSizeToFitWidth = true
        v.minimumScaleFactor = 0.8
        return v
    }()
    
    lazy var leftColorHintView: UIView = {
        let v = UIView()
        v.backgroundColor = "3498DB".color
        return v
    }()
    
    lazy var backgroundWrapper: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        return v
    }()
    
}
