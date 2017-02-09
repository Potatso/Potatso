//
//  RequestStageCell.swift
//  Potatso
//
//  Created by LEI on 7/17/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Eureka
import Cartography

final class RequestEventRow: Row<RequestEvent, RequestEventRowCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = nil
    }
}


class RequestEventRowCell: Cell<RequestEvent>, CellType {

    static let dateformatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd hh:mm:ss.SSS"
        return f
    }()

    var copyContent: String? {
        return contentLabel.text
    }

    required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setup() {
        super.setup()
        selectionStyle = .none
        preservesSuperviewLayoutMargins = false
        layoutMargins = UIEdgeInsets.zero
        separatorInset = UIEdgeInsets.zero
        contentView.addSubview(titleLabel)
        contentView.addSubview(contentLabel)
        contentView.addSubview(timeLabel)
        constrain(titleLabel, timeLabel, contentLabel, contentView) { titleLabel, timeLabel, contentLabel, contentView in
            titleLabel.leading == contentView.leading + 15
            titleLabel.top == contentView.top + 14
            timeLabel.leading == titleLabel.trailing + 10
            timeLabel.centerY == titleLabel.centerY
            timeLabel.trailing == contentView.trailing - 15
            contentLabel.top == titleLabel.bottom + 8
            contentLabel.leading == titleLabel.leading
            contentLabel.trailing == contentView.trailing - 15
            contentLabel.bottom == contentView.bottom - 14
        }
    }

    override func update() {
        super.update()
        guard let event = row.value else {
            return
        }
        titleLabel.text = event.stage.description
        timeLabel.text = RequestEventRowCell.dateformatter.string(from: Date(timeIntervalSince1970: event.timestamp))
        contentLabel.text = event.contentDescription
    }

    lazy var titleLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.systemFont(ofSize: 13)
        v.textColor = Color.Gray
        return v
    }()

    lazy var timeLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.systemFont(ofSize: 13)
        v.textColor = Color.Gray
        v.textAlignment = .right
        return v
    }()

    lazy var contentLabel: UILabel = {
        let v = UILabel()
        v.font = UIFont.systemFont(ofSize: 16)
        v.textColor = Color.Black
        v.numberOfLines = 0
        return v
    }()

}
