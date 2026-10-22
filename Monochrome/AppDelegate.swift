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

    override init() {
        defaults.register(defaults: [
            "Homepage": "https://html.duckduckgo.com/html/",
            "SearchEngine": "https://html.duckduckgo.com/html/?q="
        ])
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let homepage = defaults.string(forKey: "Homepage") ?? ""
        let searchEngine = defaults.string(forKey: "SearchEngine") ?? ""
        if homepage.isEmpty {
            defaults.set("https://html.duckduckgo.com/html/", forKey: "Homepage")
        }
        if searchEngine.isEmpty {
            defaults.set("https://html.duckduckgo.com/html/?q=", forKey: "SearchEngine")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

