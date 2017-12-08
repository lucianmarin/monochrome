//
//  Document.swift
//  Monochrome
//
//  Created by lucian on 12/4/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa
import WebKit

let defaults = UserDefaults.standard

class Document: NSDocument, WKNavigationDelegate, WKUIDelegate {
    @IBOutlet var mainWindow: NSWindow!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var back: NSButton!
    @IBOutlet weak var forward: NSButton!
    @IBOutlet weak var home: NSButton!
    @IBOutlet weak var new: NSButton!
    @IBOutlet weak var reload: NSButton!
    @IBOutlet weak var loading: NSProgressIndicator!
    
    let homeURL = URL(string: defaults.string(forKey: "Homepage") ?? "https://duckduckgo.com/html/")
    
    @IBAction func goHome(sender: NSToolbarItem) {
        let requested = URLRequest(url: homeURL!)
        webView.load(requested)
    }
    
    @IBAction func reloadOrStop(sender: NSToolbarItem) {
        if (webView.isLoading) {
            webView.stopLoading()
            loading.stopAnimation(sender)
            reload.image = NSImage(named: NSImage.Name(rawValue: "NSRefreshTemplate"))
        } else {
            webView.reload()
            loading.startAnimation(sender)
            reload.image = NSImage(named: NSImage.Name(rawValue: "NSStopProgressTemplate"))
        }
    }
    
    @IBAction func resizeSmall(sender: NSMenuItem) {
        var frame = mainWindow.frame
        frame.size = NSSize(width: 320, height: 568)
        mainWindow.setFrame(frame, display: true, animate: true)
    }

    @IBAction func resizeMedium(sender: NSMenuItem) {
        var frame = mainWindow.frame
        frame.size = NSSize(width: 360, height: 640)
        mainWindow.setFrame(frame, display: true, animate: true)
    }

    @IBAction func resizeLarge(sender: NSMenuItem) {
        var frame = mainWindow.frame
        frame.size = NSSize(width: 375, height: 667)
        mainWindow.setFrame(frame, display: true, animate: true)
    }
    
    @IBAction func openLocation(sender: NSMenuItem) {
        textField.becomeFirstResponder()
    }
    
    @IBAction func openAddress(sender: NSToolbarItem) {
        var url: String
        let searchEngine = defaults.string(forKey: "SearchEngine") ?? "https://duckduckgo.com/html/?q="
        let address = textField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if ((address?.hasPrefix("http://"))! || (address?.hasPrefix("https://"))!) {
            url = address!
        } else {
            if (address?.range(of: ".") != nil) {
                url = "http://" + address!
            } else {
                url = searchEngine + (address?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
            }
        }
        
        let requested = URLRequest(url: URL(string: url)!)
        webView.load(requested)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        reload.image = NSImage(named: NSImage.Name(rawValue: "NSStopProgressTemplate"))
        loading.usesThreadedAnimation = true
        loading.startAnimation(reload)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        textField.stringValue = (webView.url?.absoluteString)!
        webView.window?.title = webView.title!
        
        back.isEnabled = webView.canGoBack
        forward.isEnabled = webView.canGoForward
        home.isEnabled = webView.url != homeURL
        
        reload.image = NSImage(named: NSImage.Name(rawValue: "NSRefreshTemplate"))
        loading.stopAnimation(reload)
    }
    
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        if (openPanel.runModal().rawValue == 1) {
            if let url = openPanel.url {
                completionHandler([url])
            }
        }
    }
    
    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        super.windowControllerDidLoadNib(windowController)
        
        let requested = URLRequest(url: homeURL!)
        webView.load(requested)
    }
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    
    override var isDocumentEdited: Bool {
        return false
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }


}

