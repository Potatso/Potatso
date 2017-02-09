//
//  RegexUtils.swift
//  Potatso
//
//  Created by LEI on 6/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class Regex {

    let internalExpression: NSRegularExpression
    let pattern: String

    init(_ pattern: String) throws {
        self.pattern = pattern
        self.internalExpression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }

    func test(_ input: String) -> Bool {
        let matches = self.internalExpression.matches(in: input, options: NSRegularExpression.MatchingOptions.reportCompletion, range:NSMakeRange(0, input.characters.count))
        return matches.count > 0
    }

}
