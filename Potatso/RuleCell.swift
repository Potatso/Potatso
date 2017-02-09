//
//  RuleCell.swift
//  Potatso
//
//  Created by LEI on 6/7/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel

extension RuleAction {

    var color: UIColor {
        switch self {
        case .Proxy:
            return "2980B9".color
        case .Reject:
            return "E74C3C".color
        case .Direct:
            return "00A185".color
        }
    }

}

class RuleCell: UITableViewCell {

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        contentView.addSubview(actionLabel)
        constrain(titleLabel, actionLabel, contentView) { titleLabel, actionLabel, contentView in
            titleLabel.leading == contentView.leading + 15
            titleLabel.trailing == contentView.trailing - 15
            titleLabel.top == contentView.top + 12

            actionLabel.leading == titleLabel.leading
            actionLabel.trailing == titleLabel.trailing
            actionLabel.top == titleLabel.bottom + 6
            actionLabel.bottom == contentView.bottom - 12
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setRule(_ rule: Rule) {
        titleLabel.text = "\(rule.type), \(rule.value)"
        actionLabel.text = rule.action.rawValue
        actionLabel.textColor = rule.action.color
    }

    lazy var titleLabel: UILabel = {
        let v = UILabel()
        v.textColor = "404040".color
        v.font = UIFont.systemFont(ofSize: 16)
        v.numberOfLines = 2
        return v
    }()

    lazy var actionLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.systemFont(ofSize: 13)
        return v
    }()


}
