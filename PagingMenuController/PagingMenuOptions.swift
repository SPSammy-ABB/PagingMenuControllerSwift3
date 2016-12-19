//
//  PagingMenuOptions.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 5/17/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

open class PagingMenuOptions {  
    open var defaultPage = 0
    open var scrollEnabled = true // in case of using swipable cells, set false
    open var backgroundColor = UIColor.white
    open var selectedBackgroundColor = UIColor.white
    open var textColor = UIColor.lightGray
    open var selectedTextColor = UIColor.black
    open var font = UIFont.systemFont(ofSize: 16)
    open var selectedFont = UIFont.systemFont(ofSize: 16)
    open var menuPosition: MenuPosition = .top
    open var menuHeight: CGFloat = 50
    open var menuItemMargin: CGFloat = 20
    open var animationDuration: TimeInterval = 0.3
    open var deceleratingRate: CGFloat = UIScrollViewDecelerationRateNormal
    open var menuDisplayMode = MenuDisplayMode.standard(widthMode: PagingMenuOptions.MenuItemWidthMode.flexible, centerItem: false, scrollingMode: PagingMenuOptions.MenuScrollingMode.pagingEnabled)
    open var menuItemMode = MenuItemMode.underline(height: 3, color: UIColor.blue, horizontalPadding: 0, verticalPadding: 0)
    internal var menuItemCount = 0
    internal let minumumSupportedViewCount = 1
    
    public enum MenuPosition {
        case top
        case bottom
    }
    
    public enum MenuScrollingMode {
        case scrollEnabled
        case scrollEnabledAndBouces
        case pagingEnabled
    }
    
    public enum MenuItemWidthMode {
        case flexible
        case fixed(width: CGFloat)
    }
    
    public enum MenuDisplayMode {
        case standard(widthMode: MenuItemWidthMode, centerItem: Bool, scrollingMode: MenuScrollingMode)
        case segmentedControl
        case infinite(widthMode: MenuItemWidthMode)
    }
    
    public enum MenuItemMode {
        case none
        case underline(height: CGFloat, color: UIColor, horizontalPadding: CGFloat, verticalPadding: CGFloat)
        case roundRect(radius: CGFloat, horizontalPadding: CGFloat, verticalPadding: CGFloat, selectedColor: UIColor)
    }
    
    public init() {
        
    }
}
