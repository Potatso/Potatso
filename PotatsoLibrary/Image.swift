//
//  Images.swift
//  Potatso
//
//  Created by LEI on 1/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

public extension String {
    
    public var image: UIImage? {
        return UIImage(named: self)
    }
    
    public var templateImage: UIImage? {
        return UIImage(named: self)?.withRenderingMode(.alwaysTemplate)
    }
    
    public var originalImage: UIImage? {
        return UIImage(named: self)?.withRenderingMode(.alwaysOriginal)
    }

}
