//
//  AppDelegate.swift
//  Monochrome
//
//  Created by lucian on 12/4/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let homepage = defaults.string(forKey: "Homepage") ?? ""
        let searchEngine = defaults.string(forKey: "SearchEngine") ?? ""
        if homepage.isEmpty {
            defaults.set("https://duckduckgo.com/html/", forKey: "Homepage")
        }
        if searchEngine.isEmpty {
            defaults.set("https://duckduckgo.com/html/?q=", forKey: "SearchEngine")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

