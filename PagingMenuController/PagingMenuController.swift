//
//  PagingMenuController.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 3/18/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

@objc public protocol PagingMenuControllerDelegate: class {
    @objc optional func willMoveToMenuPage(_ page: Int)
    @objc optional func didMoveToMenuPage(_ page: Int)
}

public protocol PagingMenuScrollEventsDelegate: class {
    func scrollingStarted()
    func scrollingEnded()

}

open class PagingMenuController: UIViewController, UIScrollViewDelegate {

    open weak var delegate: PagingMenuControllerDelegate?
    fileprivate var scrollEventsDelegates = [PagingMenuScrollEventsDelegate]()

    fileprivate var options: PagingMenuOptions!
    open fileprivate(set) var menuView: MenuView!
    open fileprivate(set) var currentPage: Int = 0
    open fileprivate(set) var currentViewController: UIViewController!
    open fileprivate(set) var visiblePagingViewControllers = [UIViewController]()
    open fileprivate(set) var pagingViewControllers = [UIViewController]() {
        willSet {
            options.menuItemCount = newValue.count
        }
    }

    open func addScrollEventsDelegate(_ delegate: PagingMenuScrollEventsDelegate){
        scrollEventsDelegates.append(delegate)
    }

    open func removeScrollEventsDelegate(_ delegate: PagingMenuScrollEventsDelegate) {
        for (index, value) in scrollEventsDelegates.enumerated() {
            if (value === delegate) {
                scrollEventsDelegates.remove(at: index)
            }
        }
    }

    open func removeAllScrollEventsDelegates(){
        scrollEventsDelegates.removeAll()
    }

    fileprivate var contentScrollView: UIScrollView!
    fileprivate var contentView: UIView!
    fileprivate var menuItemTitles: [String] {
        get {
            return pagingViewControllers.map {
                return $0.title ?? "Menu"
            }
        }
    }
    fileprivate enum PagingViewPosition {
        case left
        case center
        case right
        case unknown

        init(order: Int) {
            switch order {
            case 0: self = .left
            case 1: self = .center
            case 2: self = .right
            default: self = .unknown
            }
        }
    }
    fileprivate var currentPosition: PagingViewPosition = .left
    fileprivate let visiblePagingViewNumber: Int = 3
    fileprivate var previousIndex: Int {
        guard case .infinite = options.menuDisplayMode else { return currentPage - 1 }

        return currentPage - 1 < 0 ? options.menuItemCount - 1 : currentPage - 1
    }
    fileprivate var nextIndex: Int {
        guard case .infinite = options.menuDisplayMode else { return currentPage + 1 }

        return currentPage + 1 > options.menuItemCount - 1 ? 0 : currentPage + 1
    }

    open func menuItemAtIndex(_ index: Int) -> MenuItemView {
        return menuView.menuItemViews[index]
    }

    fileprivate let ExceptionName = "PMCException"

    // MARK: - Lifecycle

    public init(viewControllers: [UIViewController], options: PagingMenuOptions) {
        super.init(nibName: nil, bundle: nil)

        setup(viewControllers: viewControllers, options: options)
    }

    convenience public init(viewControllers: [UIViewController]) {
        self.init(viewControllers: viewControllers, options: PagingMenuOptions())
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // position properly for Infinite mode
        menuView?.moveToMenu(page: currentPage, animated: false)
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // fix unnecessary inset for menu view when implemented by programmatically
        menuView?.contentInset.top = 0

        // position paging views correctly after view size is decided
        if let currentViewController = currentViewController {
            contentScrollView.contentOffset.x = currentViewController.view!.frame.minX
        }
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        menuView.updateMenuViewConstraints(size: size)

        coordinator.animate(alongsideTransition: { [weak self] (_) -> Void in
            guard let _ = self else { return }

            self!.view.setNeedsLayout()
            self!.view.layoutIfNeeded()

            // reset selected menu item view position
            switch self!.options.menuDisplayMode {
            case .standard, .infinite:
                self!.menuView.moveToMenu(page: self!.currentPage, animated: true)
            default: break
            }
        }, completion: nil)
    }

    // MARK: - Public

    open func setup(viewControllers: [UIViewController], options: PagingMenuOptions) {
        self.options = options
        pagingViewControllers = viewControllers
        visiblePagingViewControllers.reserveCapacity(visiblePagingViewNumber)

        // validate
        validateDefaultPage()
        validatePageNumbers()

        // cleanup
        cleanup()

        currentPage = options.defaultPage

        constructMenuView()
        constructContentScrollView()
        layoutMenuView()
        layoutContentScrollView()
        constructContentView()
        layoutContentView()
        constructPagingViewControllers()
        layoutPagingViewControllers()

        currentPosition = currentPagingViewPosition()
        currentViewController = pagingViewControllers[currentPage]
        moveToMenuPage(currentPage, animated: false)
    }

    open func rebuild(_ viewControllers: [UIViewController], options: PagingMenuOptions) {
        // cleanup properties to avoid memory leaks. This could also be placed inside the cleanup method, or in within didSet{} of the pagingViewController
        visiblePagingViewControllers.removeAll()
        currentViewController = nil

        for childViewController in childViewControllers { 
            childViewController.view.removeFromSuperview()
            childViewController.removeFromParentViewController()
        }

        // perform setup 

        setup(viewControllers: viewControllers, options: options)

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    open func moveToMenuPage(_ page: Int, animated: Bool) {
        // ignore an unexpected page number
        guard page < options.menuItemCount else { return }

        let lastPage = currentPage
        currentPage = page
        currentViewController = pagingViewControllers[page]
        menuView.moveToMenu(page: currentPage, animated: animated)

        delegate?.willMoveToMenuPage?(currentPage)

        // hide paging views if it's moving to far away
        hidePagingViewsIfNeeded(lastPage)

        let duration = animated ? options.animationDuration : 0
        UIView.animate(withDuration: duration, animations: {
            [weak self] () -> Void in
            guard let _ = self else { return }

            self!.contentScrollView.contentOffset.x = self!.currentViewController.view!.frame.minX
        }, completion: { [weak self] (_) -> Void in
            guard let _ = self else { return }

            // show paging views
            self!.visiblePagingViewControllers.forEach { $0.view.alpha = 1 }

            // reconstruct visible paging views
            self!.constructPagingViewControllers()
            self!.layoutPagingViewControllers()
            self!.view.setNeedsLayout()
            self!.view.layoutIfNeeded()

            self!.currentPosition = self!.currentPagingViewPosition()
            self!.delegate?.didMoveToMenuPage?(self!.currentPage)
        }) 
    }

    // MARK: - UISCrollViewDelegate

    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for delegate in scrollEventsDelegates {
            delegate.scrollingStarted()
        }
    }
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        for delegate in scrollEventsDelegates {
            delegate.scrollingEnded()
        }

        guard scrollView.isEqual(contentScrollView) else { return }

        let position = currentPagingViewPosition()

        // set new page number according to current moving direction
        switch position {
        case .left: currentPage = previousIndex
        case .right: currentPage = nextIndex
        default: return
        }

        delegate?.willMoveToMenuPage?(currentPage)
        menuView.moveToMenu(page: currentPage, animated: true)
        currentViewController = pagingViewControllers[currentPage]
        contentScrollView.contentOffset.x = currentViewController.view!.frame.minX

        constructPagingViewControllers()
        layoutPagingViewControllers()
        view.setNeedsLayout()
        view.layoutIfNeeded()

        currentPosition = currentPagingViewPosition()
        delegate?.didMoveToMenuPage?(currentPage)
    }

    // MARK: - UIGestureRecognizer

    internal func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        let tappedMenuView = recognizer.view as! MenuItemView
        guard let tappedPage = menuView.menuItemViews.index(of: tappedMenuView), tappedPage != currentPage else { return }

        let page = targetPage(tappedPage: tappedPage)
        moveToMenuPage(page, animated: true)
    }

    internal func handleSwipeGesture(_ recognizer: UISwipeGestureRecognizer) {
        var newPage = currentPage
        if recognizer.direction == .left {
            newPage = min(nextIndex, menuView.menuItemViews.count - 1)
        } else if recognizer.direction == .right {
            newPage = max(previousIndex, 0)
        } else {
            return
        }

        moveToMenuPage(newPage, animated: true)
    }

    // MARK: - Constructor

    fileprivate func constructMenuView() {
        menuView = MenuView(menuItemTitles: menuItemTitles, options: options)
        menuView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuView)

        addTapGestureHandlers()
        addSwipeGestureHandlersIfNeeded()
    }

    fileprivate func layoutMenuView() {
        let viewsDictionary = ["menuView": menuView]
        let metrics = ["height": options.menuHeight]
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[menuView]|", options: [], metrics: nil, views: viewsDictionary)
        let verticalConstraints: [NSLayoutConstraint]
        switch options.menuPosition {
        case .top:
            verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[menuView(height)]", options: [], metrics: metrics, views: viewsDictionary)
        case .bottom:
            verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[menuView(height)]|", options: [], metrics: metrics, views: viewsDictionary)
        }

        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)

        menuView.setNeedsLayout()
        menuView.layoutIfNeeded()
    }

    fileprivate func constructContentScrollView() {
        contentScrollView = UIScrollView(frame: CGRect.zero)
        contentScrollView.delegate = self
        contentScrollView.isPagingEnabled = true
        contentScrollView.showsHorizontalScrollIndicator = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.scrollsToTop = false
        contentScrollView.bounces = false
        contentScrollView.isScrollEnabled = options.scrollEnabled
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentScrollView)
    }

    fileprivate func layoutContentScrollView() {
        let viewsDictionary = ["contentScrollView": contentScrollView, "menuView": menuView]
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentScrollView]|", options: [], metrics: nil, views: viewsDictionary)
        let verticalConstraints: [NSLayoutConstraint]
        switch options.menuPosition {
        case .top:
            verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[menuView][contentScrollView]|", options: [], metrics: nil, views: viewsDictionary)
        case .bottom:
            verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentScrollView][menuView]", options: [], metrics: nil, views: viewsDictionary)
        }

        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
    }

    fileprivate func constructContentView() {
        contentView = UIView(frame: CGRect.zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentView)
    }

    fileprivate func layoutContentView() {
        let viewsDictionary = ["contentView": contentView, "contentScrollView": contentScrollView]
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: [], metrics: nil, views: viewsDictionary)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView(==contentScrollView)]|", options: [], metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
    }

    fileprivate func constructPagingViewControllers() {
        for (index, pagingViewController) in pagingViewControllers.enumerated() {
            // construct three child view controllers at a maximum, previous(optional), current and next(optional)
            if !shouldLoadPage(index) {
                // remove unnecessary child view controllers
                if isVisiblePagingViewController(pagingViewController) {
                    pagingViewController.willMove(toParentViewController: nil)
                    pagingViewController.view!.removeFromSuperview()
                    pagingViewController.removeFromParentViewController()

                    if let viewIndex = visiblePagingViewControllers.index(of: pagingViewController) {
                        visiblePagingViewControllers.remove(at: viewIndex)
                    }
                }
                continue
            }

            // ignore if it's already added
            if isVisiblePagingViewController(pagingViewController) {
                continue
            }

            pagingViewController.view!.frame = CGRect.zero
            pagingViewController.view!.translatesAutoresizingMaskIntoConstraints = false

            contentView.addSubview(pagingViewController.view!)
            addChildViewController(pagingViewController as UIViewController)
            pagingViewController.didMove(toParentViewController: self)

            visiblePagingViewControllers.append(pagingViewController)
        }
    }

    fileprivate func layoutPagingViewControllers() {
        // cleanup
        NSLayoutConstraint.deactivate(contentView.constraints)

        var viewsDictionary: [String: Any] = ["contentScrollView": contentScrollView]
        for (index, pagingViewController) in pagingViewControllers.enumerated() {
            if !shouldLoadPage(index) {
                continue
            }

            viewsDictionary["pagingView"] = pagingViewController.view!
            var horizontalVisualFormat = String()

            // only one view controller
            if (options.menuItemCount == options.minumumSupportedViewCount) {
                horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]|"
            } else {
                if case .infinite = options.menuDisplayMode {
                    if index == currentPage {
                        viewsDictionary["previousPagingView"] = pagingViewControllers[previousIndex].view
                        viewsDictionary["nextPagingView"] = pagingViewControllers[nextIndex].view
                        horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)][nextPagingView]"
                    } else if index == previousIndex {
                        horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]"
                    } else if index == nextIndex {
                        horizontalVisualFormat = "H:[pagingView(==contentScrollView)]|"
                    }
                } else {
                    if index == 0 || index == previousIndex {
                        horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]"
                    } else {
                        viewsDictionary["previousPagingView"] = pagingViewControllers[index - 1].view
                        if index == pagingViewControllers.count - 1 || index == nextIndex {
                            horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)]|"
                        } else {
                            horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)]"
                        }
                    }
                }
            }

            let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: horizontalVisualFormat, options: [], metrics: nil, views: viewsDictionary)
            let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[pagingView(==contentScrollView)]|", options: [], metrics: nil, views: viewsDictionary)

            NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: - Cleanup

    fileprivate func cleanup() {
        if let menuView = self.menuView, let contentScrollView = self.contentScrollView {
            menuView.removeFromSuperview()
            contentScrollView.removeFromSuperview()
        }
        currentPage = options.defaultPage
    }

    // MARK: - Gesture handler

    fileprivate func addTapGestureHandlers() {
        menuView.menuItemViews.forEach { $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(PagingMenuController.handleTapGesture(_:)))) }
    }

    fileprivate func addSwipeGestureHandlersIfNeeded() {
        switch options.menuDisplayMode {
        case .standard(_, _, .pagingEnabled): break
        case .standard: return
        case .segmentedControl: return
        case .infinite: break
        }

        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(PagingMenuController.handleSwipeGesture(_:)))
        leftSwipeGesture.direction = .left
        menuView.panGestureRecognizer.require(toFail: leftSwipeGesture)
        menuView.addGestureRecognizer(leftSwipeGesture)
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(PagingMenuController.handleSwipeGesture(_:)))
        rightSwipeGesture.direction = .right
        menuView.panGestureRecognizer.require(toFail: rightSwipeGesture)
        menuView.addGestureRecognizer(rightSwipeGesture)
    }

    // MARK: - Page controller

    fileprivate func hidePagingViewsIfNeeded(_ lastPage: Int) {
        guard lastPage != previousIndex && lastPage != nextIndex else { return }
        visiblePagingViewControllers.forEach { $0.view.alpha = 0 }
    }

    fileprivate func shouldLoadPage(_ index: Int) -> Bool {
        if case .infinite = options.menuDisplayMode {
            guard index == currentPage || index == previousIndex || index == nextIndex else { return false }
        } else {
            guard index >= previousIndex && index <= nextIndex else { return false }
        }
        return true
    }

    fileprivate func isVisiblePagingViewController(_ pagingViewController: UIViewController) -> Bool {
        return childViewControllers.contains(pagingViewController)
    }

    // MARK: - Page calculator

    fileprivate func currentPagingViewPosition() -> PagingViewPosition {
        let pageWidth = contentScrollView.frame.width
        let order = Int(ceil((contentScrollView.contentOffset.x - pageWidth / 2) / pageWidth))

        if case .infinite = options.menuDisplayMode {
            return PagingViewPosition(order: order)
        }

        // consider left edge menu as center position
        guard currentPage == 0 && contentScrollView.contentSize.width < (pageWidth * CGFloat(visiblePagingViewNumber)) else { return PagingViewPosition(order: order) }
        return PagingViewPosition(order: order + 1)
    }

    fileprivate func targetPage(tappedPage: Int) -> Int {
        guard case let .standard(_, _, scrollingMode) = options.menuDisplayMode else { return tappedPage }
        guard case .pagingEnabled = scrollingMode else { return tappedPage }
        return tappedPage < currentPage ? currentPage - 1 : currentPage + 1
    }

    // MARK: - Validator

    fileprivate func validateDefaultPage() {
        guard options.defaultPage >= options.menuItemCount || options.defaultPage < 0 else { return }

        NSException(name: NSExceptionName(rawValue: ExceptionName), reason: "default page is invalid", userInfo: nil).raise()
    }

    fileprivate func validatePageNumbers() {
        guard case .infinite = options.menuDisplayMode else { return }
        guard options.menuItemCount < visiblePagingViewNumber else { return }

        NSException(name: NSExceptionName(rawValue: ExceptionName), reason: "the number of view controllers should be more than three with Infinite display mode", userInfo: nil).raise()
    }
}
