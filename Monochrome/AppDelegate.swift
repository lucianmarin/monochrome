//
//  AppDelegate.swift
//  Monochrome
//
//  Created by lucian on 12/4/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

enum SearchProvider: String, CaseIterable {
    case brave
    case duckDuckGo = "duckduckgo"
    case google
    case custom

    static let defaultsKey = "SearchProvider"
    static let homepageKey = "Homepage"
    static let searchEngineKey = "SearchEngine"
    static let customHomepageKey = "CustomHomepage"
    static let customSearchEngineKey = "CustomSearchEngine"

    static let defaultHomepage = "https://duckduckgo.com/"
    static let defaultSearchEngine = "https://duckduckgo.com/?q="

    var title: String {
        switch self {
        case .brave: return "Brave"
        case .duckDuckGo: return "DuckDuckGo"
        case .google: return "Google"
        case .custom: return "Custom"
        }
    }

    var homepage: String? {
        switch self {
        case .brave: return "https://search.brave.com/"
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .google: return "https://www.google.com/"
        case .custom: return nil
        }
    }

    var searchEngine: String? {
        switch self {
        case .brave: return "https://search.brave.com/search?q="
        case .duckDuckGo: return "https://duckduckgo.com/?q="
        case .google: return "https://www.google.com/search?q="
        case .custom: return nil
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard

    override init() {
        defaults.register(defaults: [
            SearchProvider.defaultsKey: SearchProvider.duckDuckGo.rawValue,
            SearchProvider.homepageKey: SearchProvider.defaultHomepage,
            SearchProvider.searchEngineKey: SearchProvider.defaultSearchEngine,
            SearchProvider.customHomepageKey: SearchProvider.defaultHomepage,
            SearchProvider.customSearchEngineKey: SearchProvider.defaultSearchEngine,
            "ShowStatusBar": false
        ])
        super.init()
        syncProviderDefaults()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        syncProviderDefaults()
    }

    private func syncProviderDefaults() {
        let providerRaw = defaults.string(forKey: SearchProvider.defaultsKey) ?? SearchProvider.duckDuckGo.rawValue
        let provider = SearchProvider(rawValue: providerRaw) ?? .duckDuckGo

        if let presetHomepage = provider.homepage, let presetSearchEngine = provider.searchEngine {
            defaults.set(presetHomepage, forKey: SearchProvider.homepageKey)
            defaults.set(presetSearchEngine, forKey: SearchProvider.searchEngineKey)
        } else {
            let homepage = defaults.string(forKey: SearchProvider.homepageKey) ?? ""
            let searchEngine = defaults.string(forKey: SearchProvider.searchEngineKey) ?? ""
            if homepage.isEmpty {
                defaults.set(SearchProvider.defaultHomepage, forKey: SearchProvider.homepageKey)
            }
            if searchEngine.isEmpty {
                defaults.set(SearchProvider.defaultSearchEngine, forKey: SearchProvider.searchEngineKey)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

