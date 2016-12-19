//
//  MenuView.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 5/9/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

open class MenuView: UIScrollView {  
    
    open fileprivate(set) var menuItemViews = [MenuItemView]()
    fileprivate var sortedMenuItemViews = [MenuItemView]()
    fileprivate var options: PagingMenuOptions!
    fileprivate var contentView: UIView!
    fileprivate var underlineView: UIView!
    fileprivate var roundRectView: UIView!
    fileprivate var currentPage: Int = 0
    
    // MARK: - Lifecycle
    
    internal init(menuItemTitles: [String], options: PagingMenuOptions) {
        super.init(frame: CGRect.zero)
        
        self.options = options
        
        setupScrollView()
        constructContentView()
        layoutContentView()
        constructRoundRectViewIfNeeded()
        constructMenuItemViews(titles: menuItemTitles)
        layoutMenuItemViews()
        constructUnderlineViewIfNeeded()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        adjustmentContentInsetIfNeeded()
    }
    
    // MARK: - Public method
    
    internal func moveToMenu(page: Int, animated: Bool) {
        let duration = animated ? options.animationDuration : 0
        currentPage = page
        
        // hide menu view when constructing itself
        if !animated {
            alpha = 0
        }
        UIView.animate(withDuration: duration, animations: { [weak self] () -> Void in
            guard let _ = self else { return }
            
            self!.focusMenuItem()
            self!.positionMenuItemViews()
        }, completion: { [weak self] (_) in
            guard let _ = self else { return }
            
            // relayout menu item views dynamically
            if case .infinite = self!.options.menuDisplayMode {
                self!.relayoutMenuItemViews()
            }
            self!.positionMenuItemViews()
            self!.setNeedsLayout()
            self!.layoutIfNeeded()
            
            // show menu view when constructing is done
            if !animated {
                self!.alpha = 1
            }
        }) 
    }
    
    internal func updateMenuViewConstraints(size: CGSize) {
        if case .segmentedControl = options.menuDisplayMode {
            menuItemViews.forEach { $0.updateLabelConstraints(size: size) }
        }
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()

        animateUnderlineViewIfNeeded()
        animateRoundRectViewIfNeeded()
    }
    
    // MARK: - Private method
    
    fileprivate func setupScrollView() {
        backgroundColor = options.backgroundColor
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = bounces()
        isScrollEnabled = scrollEnabled()
        decelerationRate = options.deceleratingRate
        scrollsToTop = false
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    fileprivate func constructContentView() {
        contentView = UIView(frame: CGRect.zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
    }
    
    fileprivate func layoutContentView() {
        let viewsDictionary = ["contentView": contentView, "scrollView": self]
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: [], metrics: nil, views: viewsDictionary)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView(==scrollView)]|", options: [], metrics: nil, views: viewsDictionary)
        
        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
    }
    
    fileprivate func constructMenuItemViews(titles: [String]) {
        for i in 0..<options.menuItemCount {
            let menuItemView = MenuItemView(title: titles[i], options: options)
            menuItemView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(menuItemView)
            
            menuItemViews.append(menuItemView)
        }
        
        sortMenuItemViews()
    }
    
    fileprivate func sortMenuItemViews() {
        if sortedMenuItemViews.count > 0 {
            sortedMenuItemViews.removeAll()
        }
        
        if case .infinite = options.menuDisplayMode {
            for i in 0..<options.menuItemCount {
                let index = rawIndex(i)
                sortedMenuItemViews.append(menuItemViews[index])
            }
        } else {
            sortedMenuItemViews = menuItemViews
        }
    }
    
    fileprivate func layoutMenuItemViews() {
        NSLayoutConstraint.deactivate(contentView.constraints)
        
        for (index, menuItemView) in sortedMenuItemViews.enumerated() {
            let visualFormat: String;
            var viewsDicrionary = ["menuItemView": menuItemView]
            if index == 0 {
                visualFormat = "H:|[menuItemView]"
            } else  {
                viewsDicrionary["previousMenuItemView"] = sortedMenuItemViews[index - 1]
                if index == sortedMenuItemViews.count - 1 {
                    visualFormat = "H:[previousMenuItemView][menuItemView]|"
                } else {
                    visualFormat = "H:[previousMenuItemView][menuItemView]"
                }
            }
            let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: [], metrics: nil, views: viewsDicrionary)
            let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[menuItemView]|", options: [], metrics: nil, views: viewsDicrionary)
            
            NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    fileprivate func constructUnderlineViewIfNeeded() {
        guard case let .underline(height, color, horizontalPadding, verticalPadding) = options.menuItemMode else { return }
        
        let width = menuItemViews[currentPage].bounds.width - horizontalPadding * 2
        underlineView = UIView(frame: CGRect(x: horizontalPadding, y: options.menuHeight - (height + verticalPadding), width: width, height: height))
        underlineView.backgroundColor = color
        contentView.addSubview(underlineView)
    }
    
    fileprivate func constructRoundRectViewIfNeeded() {
        guard case let .roundRect(radius, _, verticalPadding, selectedColor) = options.menuItemMode else { return }
        
        let height = options.menuHeight - verticalPadding * 2
        roundRectView = UIView(frame: CGRect(x: 0, y: verticalPadding, width: 0, height: height))
        roundRectView.frame.origin.y = verticalPadding
        roundRectView.isUserInteractionEnabled = true
        roundRectView.layer.cornerRadius = radius
        roundRectView.backgroundColor = selectedColor
        contentView.addSubview(roundRectView)
    }
    
    fileprivate func animateUnderlineViewIfNeeded() {
        guard case let .underline(_, _, horizontalPadding, _) = options.menuItemMode else { return }
        
        if let underlineView = underlineView {
            let targetFrame = menuItemViews[currentPage].frame
            underlineView.frame.origin.x = targetFrame.minX + horizontalPadding
            underlineView.frame.size.width = targetFrame.width - horizontalPadding * 2
        }
    }
    
    fileprivate func animateRoundRectViewIfNeeded() {
        guard case let .roundRect(_, horizontalPadding, _, _) = options.menuItemMode else { return }
        
        if let roundRectView = roundRectView {
            let targetFrame = menuItemViews[currentPage].frame
            roundRectView.frame.origin.x = targetFrame.minX + horizontalPadding
            roundRectView.frame.size.width = targetFrame.width - horizontalPadding * 2
        }
    }

    fileprivate func relayoutMenuItemViews() {
        sortMenuItemViews()
        layoutMenuItemViews()
    }

    fileprivate func positionMenuItemViews() {
        contentOffset.x = targetContentOffsetX()
        animateUnderlineViewIfNeeded()
        animateRoundRectViewIfNeeded()
    }
    
    fileprivate func bounces() -> Bool {
        guard case let .standard(_, _, scrollingMode) = options.menuDisplayMode else { return false }
        guard case .scrollEnabledAndBouces = scrollingMode else { return false }
        return true
    }
    
    fileprivate func scrollEnabled() -> Bool {
        guard case let .standard(_, _, scrollingMode) = options.menuDisplayMode else { return false }
        
        switch scrollingMode {
        case .scrollEnabled, .scrollEnabledAndBouces: return true
        case .pagingEnabled: return false
        }
    }
    
    fileprivate func adjustmentContentInsetIfNeeded() {
        switch options.menuDisplayMode {
        case let .standard(_, centerItem, _) where centerItem: break
        default: return
        }
        
        let firstMenuView = menuItemViews.first!
        let lastMenuView = menuItemViews.last!
        
        var inset = contentInset
        let halfWidth = frame.width / 2
        inset.left = halfWidth - firstMenuView.frame.width / 2
        inset.right = halfWidth - lastMenuView.frame.width / 2
        contentInset = inset
    }
    
    fileprivate func targetContentOffsetX() -> CGFloat {
        switch options.menuDisplayMode {
        case let .standard(_, centerItem, _) where centerItem:
            return centerOfScreenWidth()
        case .segmentedControl:
            return contentOffset.x
        case .infinite:
            return centerOfScreenWidth()
        default:
            return contentOffsetXForCurrentPage()
        }
    }
    
    fileprivate func centerOfScreenWidth() -> CGFloat {
        return menuItemViews[currentPage].frame.midX - UIScreen.main.bounds.width / 2
    }
    
    fileprivate func contentOffsetXForCurrentPage() -> CGFloat {
        guard menuItemViews.count > options.minumumSupportedViewCount else { return 0.0 }
        
        let ratio = CGFloat(currentPage) / CGFloat(menuItemViews.count - 1)
        return (contentSize.width - frame.width) * ratio
    }
    
    fileprivate func focusMenuItem() {
        // make selected item focused
        menuItemViews.forEach { $0.focusLabel(menuItemViews.index(of: $0) == currentPage) }

        // make selected item foreground
        sortedMenuItemViews.forEach { $0.layer.zPosition = menuItemViews.index(of: $0) == currentPage ? 0 : -1 }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    fileprivate func rawIndex(_ sortedIndex: Int) -> Int {
        let count = options.menuItemCount
        let startIndex = currentPage - count / 2
        return (startIndex + sortedIndex + count) % count
    }
}
