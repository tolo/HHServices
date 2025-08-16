//
//  AppDelegate.swift
//  PublisherSample
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let screenBounds = UIScreen.main.bounds
        window = UIWindow(frame: screenBounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}