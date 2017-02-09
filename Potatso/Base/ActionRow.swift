//
//  ActionRow.swift
//  Potatso
//
//  Created by LEI on 8/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

public final class ActionRow: _LabelRow, RowType {

    public required init(tag: String?) {
        super.init(tag: tag)
    }

    public override func updateCell() {
        super.updateCell()
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
    }

    public override func didSelect() {
        super.didSelect()
        cell.setSelected(false, animated: true)
    }

}
