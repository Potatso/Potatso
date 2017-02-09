//
//  RuleSetCell.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel

class RuleSetCell: UITableViewCell {

    let group = ConstraintGroup()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        preservesSuperviewLayoutMargins = false
        layoutMargins = UIEdgeInsets.zero
        separatorInset = UIEdgeInsets.zero
        contentView.addSubview(titleLabel)
        contentView.addSubview(countLabel)
        contentView.addSubview(leftHintView)
        contentView.addSubview(descLabel)
        contentView.addSubview(subscribeFlagLabel)
//        contentView.addSubview(avatarImageView)
//        contentView.addSubview(authorNameLabel)
//        contentView.addSubview(updateAtLabel)
        constrain(contentView, self) { contentView, superview in
            contentView.edges == superview.edges
        }
        countLabel.setContentHuggingPriority(UILayoutPriorityRequired, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
        constrain(titleLabel, countLabel, contentView) { titleLabel, countLabel, contentView in
            titleLabel.leading == contentView.leading + 15
            titleLabel.top == contentView.top + 13
            countLabel.leading == titleLabel.trailing + 15

            countLabel.trailing == contentView.trailing - 15
            countLabel.centerY == titleLabel.centerY
        }
        constrain(descLabel, leftHintView, titleLabel, countLabel) { descLabel, leftHintView, titleLabel, countLabel in
            leftHintView.leading == titleLabel.leading
            leftHintView.top == titleLabel.bottom + 11
            leftHintView.width == 2

            descLabel.leading == leftHintView.trailing + 5
            descLabel.top == leftHintView.top
            descLabel.bottom == leftHintView.bottom
            descLabel.trailing == countLabel.trailing
        }
        constrain(leftHintView, subscribeFlagLabel) { leftHintView, subscribeFlagLabel in
            subscribeFlagLabel.leading == leftHintView.leading
            subscribeFlagLabel.top == leftHintView.bottom + 8
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setRuleSet(_ ruleSet: RuleSet, showFullDescription: Bool = false, showSubscribe: Bool = false) {
        titleLabel.text = ruleSet.name
        var count = 0
        if ruleSet.ruleCount > 0 {
            count = ruleSet.ruleCount
        }else {
            count = ruleSet.rules.count
        }
        if count > 1 {
            countLabel.text = String(format: "%d rules".localized(),  count)
        }else {
            countLabel.text = String(format: "%d rule".localized(), count)
        }
        descLabel.text = ruleSet.desc
        descLabel.numberOfLines = showFullDescription ? 0 : 2
        let bottomView: UIView
        if showSubscribe && ruleSet.isSubscribe {
            subscribeFlagLabel.isHidden = false
            bottomView = subscribeFlagLabel
        }else {
            subscribeFlagLabel.isHidden = true
            if ruleSet.desc.characters.count > 0 {
                bottomView = descLabel
            }else{
                bottomView = countLabel
            }
        }
        subscribeFlagLabel.text = "Subscribe".localized()
        constrain(bottomView, contentView, replace: group) { bottom, contentView in
            bottom.bottom == contentView.bottom - 15
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        subscribeFlagLabel.backgroundColor = "16A085".color
        leftHintView.backgroundColor = "DEDEDE".color
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        subscribeFlagLabel.backgroundColor = "16A085".color
        leftHintView.backgroundColor = "DEDEDE".color
    }

    lazy var titleLabel: UILabel = {
        let v = UILabel()
        v.textColor = "000".color
        v.font = UIFont.systemFont(ofSize: 17)
        return v
    }()

    lazy var countLabel: UILabel = {
        let v = UILabel()
        v.textColor = "404040".color
        v.font = UIFont.systemFont(ofSize: 14)
        return v
    }()

    lazy var descLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5B5B5B".color
        v.font = UIFont.systemFont(ofSize: 13)
        v.numberOfLines = 2
        return v
    }()

    lazy var leftHintView: UIView = {
        let v = UIView()
        v.backgroundColor = "DEDEDE".color
        return v
    }()

    lazy var avatarImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        return v
    }()

    lazy var authorNameLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5D5D5D".color
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()

    lazy var updateAtLabel: UILabel = {
        let v = UILabel()
        v.textColor = "5D5D5D".color
        v.font = UIFont.systemFont(ofSize: 12)
        return v
    }()

    lazy var subscribeFlagLabel: PaddingLabel = {
        let v = PaddingLabel()
        v.textColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        v.font = UIFont.systemFont(ofSize: 10)
        v.padding = UIEdgeInsetsMake(3, 10, 3, 10)
        v.layer.cornerRadius = 3
        v.layer.masksToBounds = true
        v.clipsToBounds = true
        return v
    }()

}
