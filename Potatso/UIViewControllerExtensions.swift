//
//  UIViewControllerExtensions.swift
//  Potatso
//
//  Created by LEI on 12/12/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import UIKit
import Aspects

extension UIViewController: UIGestureRecognizerDelegate  {
    
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        // make sure this isn't a subclass
        if self !== UIViewController.self {
            return
        }
        
        dispatch_once(&Static.token) {
            UIViewController.aspectHook(#selector(viewDidLoad), swizzledSelector: #selector(ics_viewDidLoad))
            UIViewController.aspectHook(#selector(viewWillAppear(_:)), swizzledSelector: #selector(ics_viewWillAppear(_:)))
            UIViewController.aspectHook(#selector(viewDidAppear(_:)), swizzledSelector: #selector(ics_viewDidAppear(_:)))
            UIViewController.aspectHook(#selector(viewWillDisappear(_:)), swizzledSelector: #selector(ics_viewWillDisappear(_:)))
        }
    }
    
    // MARK: - Method Swizzling
    
    func ics_viewWillAppear(animated: Bool) {
        self.ics_viewWillAppear(animated)
        if let navVC = self.navigationController {
            if !isModal() {
                showLeftBackButton(navVC.viewControllers.count > 1)
            }
        }
    }
    
    func ics_viewDidLoad() {
        self.ics_viewDidLoad()
    }
    
    func ics_viewDidAppear(animated: Bool) {
        self.ics_viewDidAppear(animated)
        if let navVC = self.navigationController {
            enableSwipeGesture(navVC.viewControllers.count > 1)
        }
    }
    
    func ics_viewWillDisappear(animated: Bool) {
        self.ics_viewWillDisappear(animated)
    }
    
    func showLeftBackButton(shouldShow: Bool) {
        if shouldShow {
            let backItem = UIBarButtonItem(image: "Back".templateImage, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(pop))
            navigationItem.leftBarButtonItem = backItem
        }else{
            navigationItem.leftBarButtonItem = nil
        }
    }
    
    func enableSwipeGesture(shouldShow: Bool) {
        if shouldShow {
            navigationController?.interactivePopGestureRecognizer?.delegate = self
            navigationController?.interactivePopGestureRecognizer?.enabled = true
        }else{
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
            navigationController?.interactivePopGestureRecognizer?.enabled = false
        }
    }

    func addChildVC(child: UIViewController) {
        view.addSubview(child.view)
        addChildViewController(child)
        child.didMoveToParentViewController(self)
    }

    func removeChildVC(child: UIViewController) {
        child.willMoveToParentViewController(nil)
        child.view.removeFromSuperview()
        child.removeFromParentViewController()
    }
    
    func pop() {
        navigationController?.popViewControllerAnimated(true)
    }
    
    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func close() {
        if let navVC = self.navigationController where navVC.viewControllers.count > 1 {
            pop()
        }else {
            dismiss()
        }
    }

    func isModal() -> Bool {
        if self.presentingViewController != nil {
            return true
        }
        if self.presentingViewController?.presentedViewController == self {
            return true
        }
        if self.navigationController?.presentingViewController?.presentedViewController == self.navigationController  {
            return true
        }
        if self.tabBarController?.presentingViewController is UITabBarController {
            return true
        }
        return false
    }

}