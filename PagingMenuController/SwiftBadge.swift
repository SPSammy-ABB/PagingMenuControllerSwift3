//
//  SwiftBadge.swift
//  swift-badge
//
//  Created by Evgenii Neumerzhitckii on 1/10/2014.
//  Copyright (c) 2014 The Exchange Group Pty Ltd. All rights reserved.
//

import UIKit

class SwiftBadge: UILabel {
    
    var defaultInsets = CGSize(width: 2, height: 2)
    var actualInsets = CGSize() 
    
    convenience init() {
        self.init(frame: CGRect())
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        layer.backgroundColor = UIColor.red.cgColor
        textColor = UIColor.white
        
        // Shadow
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 0.5
        layer.shadowColor = UIColor.black.cgColor
    }
    
    // Add custom insets
    // --------------------
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        
        actualInsets = defaultInsets
        let rectWithDefaultInsets = rect.insetBy(dx: -actualInsets.width, dy: -actualInsets.height)
        
        // If width is less than height
        // Adjust the width insets to make it look round
        if rectWithDefaultInsets.width < rectWithDefaultInsets.height {
            actualInsets.width = (rectWithDefaultInsets.height - rect.width) / 2
        }
        
        return rect.insetBy(dx: -actualInsets.width, dy: -actualInsets.height)
    }
    
    override func drawText(in rect: CGRect) {
        
        layer.cornerRadius = rect.height / 2
        
        let insets = UIEdgeInsets(
            top: actualInsets.height,
            left: actualInsets.width,
            bottom: actualInsets.height,
            right: actualInsets.width)
        
        let rectWithoutInsets = UIEdgeInsetsInsetRect(rect, insets)
        
        super.drawText(in: rectWithoutInsets)
    }
}
