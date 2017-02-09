//
//  FlatButton.swift
//  Potatso
//
//  Created by LEI on 6/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICDMaterialActivityIndicatorView
import Cartography


class FlatButton: UIButton {

    var animating = false {
        didSet(o) {
            if animating {
                indicator.startAnimating()
            }else {
                indicator.stopAnimating()
            }
            UIView.animate(withDuration: 0.5, animations: {
                self.titleLabel?.alpha = self.animating ? 0 : 1
            })
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicator)
        constrain(indicator, self) { indicator, view in
            indicator.center == view.center
            indicator.width == 15
            indicator.height == 15
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var indicator: ICDMaterialActivityIndicatorView = {
        let v = ICDMaterialActivityIndicatorView(activityIndicatorStyle: ICDMaterialActivityIndicatorViewStyleSmall)
        v?.hidesWhenStopped = true
        v?.color = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        return v!
    }()
    
}
