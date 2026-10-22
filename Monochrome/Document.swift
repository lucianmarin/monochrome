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

class Document: NSDocument, WKNavigationDelegate, WKUIDelegate, NSToolbarDelegate {
    @IBOutlet var mainWindow: NSWindow!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet var textField: NSTextField!
    @IBOutlet var back: NSButton!
    @IBOutlet var forward: NSButton!
    @IBOutlet var home: NSButton!
    @IBOutlet var new: NSButton!
    @IBOutlet var reload: NSButton!
    @IBOutlet var loading: NSProgressIndicator!

    private enum ToolbarItemID {
        static let back = NSToolbarItem.Identifier("Back")
        static let forward = NSToolbarItem.Identifier("Forward")
        static let home = NSToolbarItem.Identifier("Home")
        static let address = NSToolbarItem.Identifier("Address")
        static let reload = NSToolbarItem.Identifier("Reload")
        static let new = NSToolbarItem.Identifier("New")
        static let loading = NSToolbarItem.Identifier("Loading")
    }

    private var observations: [NSKeyValueObservation] = []

    var homeURL: URL {
        let homepage = defaults.string(forKey: "Homepage")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: homepage), !homepage.isEmpty {
            return url
        }
        return URL(string: "https://duckduckgo.com/html/")!
    }

    private func toolbarSymbol(_ symbolName: String, fallback: NSImage.Name, description: String) -> NSImage? {
        if #available(macOS 11.0, *),
           let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular, scale: .medium)
            return image.withSymbolConfiguration(config) ?? image
        }
        return NSImage(named: fallback)
    }

    @IBAction func goBack(_ sender: Any?) {
        webView?.goBack(sender)
    }

    @IBAction func goForward(_ sender: Any?) {
        webView?.goForward(sender)
    }

    @IBAction func stopLoading(_ sender: Any?) {
        webView?.stopLoading(sender)
    }

    @IBAction func reload(_ sender: Any?) {
        webView?.reload(sender)
    }

    @IBAction func reloadFromOrigin(_ sender: Any?) {
        webView?.reloadFromOrigin(sender)
    }

    @IBAction func goHome(sender: Any) {
        let requested = URLRequest(url: homeURL)
        webView.load(requested)
    }

    @IBAction func reloadOrStop(sender: Any) {
        if webView.isLoading {
            webView.stopLoading()
            updateLoadingState(isLoading: false)
        } else {
            webView.reload()
            updateLoadingState(isLoading: true)
        }
    }

    private func resizeWindow(width: CGFloat, height: CGFloat, animate: Bool = true) {
        guard let window = mainWindow ?? windowControllers.first?.window else { return }
        var frame = window.frame
        let targetSize = NSSize(width: width, height: height)
        frame.origin.y += frame.size.height - targetSize.height
        frame.size = targetSize
        if let screen = window.screen ?? NSScreen.main {
            frame = window.constrainFrameRect(frame, to: screen)
        }
        window.setFrame(frame, display: true, animate: animate)
    }

    @IBAction func resize5s(sender: Any) {
        resizeWindow(width: 320, height: 568)
    }

    @IBAction func resizeMini(sender: Any) {
        resizeWindow(width: 360, height: 780)
    }

    @IBAction func resizeSE(sender: Any) {
        resizeWindow(width: 375, height: 667)
    }

    @IBAction func resizeE(sender: Any) {
        resizeWindow(width: 390, height: 844)
    }

    @IBAction func resizePro(sender: Any) {
        resizeWindow(width: 402, height: 874)
    }

    @IBAction func resizeMax(sender: Any) {
        resizeWindow(width: 440, height: 956)
    }

    @IBAction func openLocation(sender: Any) {
        guard let window = mainWindow ?? windowControllers.first?.window else { return }
        window.makeFirstResponder(textField)
        textField?.selectText(sender)
    }

    @IBAction func openAddress(sender: Any) {
        let searchEngine = defaults.string(forKey: "SearchEngine") ?? "https://duckduckgo.com/html/?q="
        guard let address = textField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else {
            return
        }

        let urlString: String
        if address.hasPrefix("http://") || address.hasPrefix("https://") {
            urlString = address
        } else if !address.contains(" ") && address.contains(".") {
            urlString = "https://" + address
        } else {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=?")
            let encoded = address.addingPercentEncoding(withAllowedCharacters: allowed) ?? address
            urlString = searchEngine + encoded
        }

        guard let targetURL = URL(string: urlString) else { return }
        webView.load(URLRequest(url: targetURL))
        mainWindow?.makeFirstResponder(webView)
    }

    private func updateLoadingState(isLoading: Bool) {
        if isLoading {
            reload?.image = toolbarSymbol("xmark", fallback: NSImage.stopProgressTemplateName, description: "Stop")
            loading?.usesThreadedAnimation = true
            loading?.startAnimation(reload)
        } else {
            reload?.image = toolbarSymbol("arrow.clockwise", fallback: NSImage.refreshTemplateName, description: "Reload")
            loading?.stopAnimation(reload)
        }
    }

    private func updateNavigationState() {
        back?.isEnabled = webView?.canGoBack ?? false
        forward?.isEnabled = webView?.canGoForward ?? false
        home?.isEnabled = webView?.url != homeURL

        if let currentURL = webView?.url?.absoluteString,
           mainWindow?.firstResponder != textField?.currentEditor() {
            textField?.stringValue = currentURL
        }

        if let title = webView?.title, !title.isEmpty {
            displayName = title
            (mainWindow ?? webView?.window)?.title = title
        }
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(goBack(_:)):
            return webView?.canGoBack ?? false
        case #selector(goForward(_:)):
            return webView?.canGoForward ?? false
        case #selector(stopLoading(_:)):
            return webView?.isLoading ?? false
        case #selector(reload(_:)), #selector(reloadFromOrigin(_:)):
            return webView?.url != nil
        case #selector(goHome(sender:)):
            return webView?.url != homeURL
        default:
            return super.validateUserInterfaceItem(item)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateLoadingState(isLoading: true)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateLoadingState(isLoading: true)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateLoadingState(isLoading: false)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateLoadingState(isLoading: false)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateLoadingState(isLoading: false)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        if openPanel.runModal() == .OK {
            completionHandler(openPanel.urls)
        } else {
            completionHandler(nil)
        }
    }

    private func makeToolbarButton(symbol: String, fallback: NSImage.Name, label: String, action: Selector, target: AnyObject?) -> NSButton {
        let image = toolbarSymbol(symbol, fallback: fallback, description: label) ?? NSImage()
        let button = NSButton(image: image, target: target, action: action)
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = label
        return button
    }

    private func setupToolbar(for window: NSWindow) {
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .expanded
        }

        back = makeToolbarButton(symbol: "chevron.left", fallback: NSImage.goBackTemplateName, label: "Back", action: #selector(goBack(_:)), target: self)
        back.isEnabled = false

        forward = makeToolbarButton(symbol: "chevron.right", fallback: NSImage.goForwardTemplateName, label: "Forward", action: #selector(goForward(_:)), target: self)
        forward.isEnabled = false

        home = makeToolbarButton(symbol: "house", fallback: NSImage.homeTemplateName, label: "Home", action: #selector(goHome(sender:)), target: self)

        reload = makeToolbarButton(symbol: "arrow.clockwise", fallback: NSImage.refreshTemplateName, label: "Reload", action: #selector(reloadOrStop(sender:)), target: self)

        new = makeToolbarButton(symbol: "plus", fallback: NSImage.addTemplateName, label: "New", action: #selector(NSDocumentController.newDocument(_:)), target: nil)

        let addressField = NSTextField()
        addressField.bezelStyle = .roundedBezel
        addressField.usesSingleLineMode = true
        addressField.lineBreakMode = .byTruncatingTail
        addressField.isEditable = true
        addressField.isSelectable = true
        addressField.cell?.isScrollable = true
        addressField.cell?.sendsActionOnEndEditing = false
        addressField.placeholderString = "Search or enter address"
        addressField.target = self
        addressField.action = #selector(openAddress(sender:))
        addressField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addressField.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            addressField.widthAnchor.constraint(lessThanOrEqualToConstant: 400)
        ])
        textField = addressField

        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        loading = indicator

        let toolbar = NSToolbar(identifier: "MonochromeToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        window.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarItemID.back,
            ToolbarItemID.reload,
            ToolbarItemID.home,
            ToolbarItemID.address,
            ToolbarItemID.forward,
            ToolbarItemID.new,
            ToolbarItemID.loading,
            .space,
            .flexibleSpace
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarItemID.back,
            ToolbarItemID.reload,
            ToolbarItemID.home,
            ToolbarItemID.address
        ]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case ToolbarItemID.back:
            item.label = "Back"
            item.paletteLabel = "Back"
            item.view = flag ? back : makeToolbarButton(symbol: "chevron.left", fallback: NSImage.goBackTemplateName, label: "Back", action: #selector(goBack(_:)), target: self)
        case ToolbarItemID.forward:
            item.label = "Forward"
            item.paletteLabel = "Forward"
            item.view = flag ? forward : makeToolbarButton(symbol: "chevron.right", fallback: NSImage.goForwardTemplateName, label: "Forward", action: #selector(goForward(_:)), target: self)
        case ToolbarItemID.home:
            item.label = "Home"
            item.paletteLabel = "Home"
            item.view = flag ? home : makeToolbarButton(symbol: "house", fallback: NSImage.homeTemplateName, label: "Home", action: #selector(goHome(sender:)), target: self)
        case ToolbarItemID.address:
            item.label = "Address"
            item.paletteLabel = "Address"
            if flag {
                item.view = textField
            } else {
                let sample = NSTextField()
                sample.bezelStyle = .roundedBezel
                sample.placeholderString = "Address"
                item.view = sample
            }
        case ToolbarItemID.reload:
            item.label = "Reload"
            item.paletteLabel = "Reload"
            item.view = flag ? reload : makeToolbarButton(symbol: "arrow.clockwise", fallback: NSImage.refreshTemplateName, label: "Reload", action: #selector(reloadOrStop(sender:)), target: self)
        case ToolbarItemID.new:
            item.label = "New"
            item.paletteLabel = "New"
            item.view = flag ? new : makeToolbarButton(symbol: "plus", fallback: NSImage.addTemplateName, label: "New", action: #selector(NSDocumentController.newDocument(_:)), target: nil)
        case ToolbarItemID.loading:
            item.label = "Loading"
            item.paletteLabel = "Loading"
            item.view = loading
        default:
            return nil
        }
        return item
    }

    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        super.windowControllerDidLoadNib(windowController)

        if let window = windowController.window ?? mainWindow {
            setupToolbar(for: window)
            resizeWindow(width: 375, height: 667, animate: false)
        }
        updateNavigationState()

        observations = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                self?.updateLoadingState(isLoading: webView.isLoading)
            }
        ]

        let requested = URLRequest(url: homeURL)
        webView.load(requested)
    }

    override init() {
        super.init()
    }

    override var isDocumentEdited: Bool {
        return false
    }

    override class var autosavesInPlace: Bool {
        return false
    }

    override var windowNibName: NSNib.Name? {
        return NSNib.Name("Document")
    }

    override func data(ofType typeName: String) throws -> Data {
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
}

