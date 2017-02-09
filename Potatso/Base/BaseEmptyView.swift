//
//  EmptyView.swift
//  Potatso
//
//  Created by LEI on 4/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

class BaseEmptyView: UIView {
    
    var title: String? {
        didSet(o) {
            titleLabel.text = title
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(sadView)
        addSubview(titleLabel)
        titleLabel.text = title
        constrain(sadView, titleLabel, self) { sadView, titleLabel, superView in
            sadView.centerX == superView.centerX
            sadView.width == 80
            sadView.height == 102
            sadView.centerY == superView.centerY - 120
            
            titleLabel.centerX == sadView.centerX
            titleLabel.top == sadView.bottom + 32
            titleLabel.leading == superView.leading + 40
            titleLabel.trailing == superView.trailing - 40
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var sadView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "User")
        v.contentMode = .scaleAspectFit
        return v
    }()
    
    lazy var titleLabel: UILabel = {
        let v = UILabel()
        v.textColor = "808080".color
        v.font = UIFont.systemFont(ofSize: 15)
        v.textAlignment = .center
        v.numberOfLines = 0
        return v
    }()
    
}
