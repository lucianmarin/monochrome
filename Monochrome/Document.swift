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

final class BrowsingHistory {
    static let shared = BrowsingHistory()

    private let storageKey = "BrowsingHistory"
    private let maxEntries = 1000
    private var entries: [String] = []

    private init() {
        load()
    }

    static func compactString(for url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }

        components.scheme = scheme
        components.host = host
        components.fragment = nil

        guard var result = components.string else { return nil }

        if result.hasPrefix("https://") {
            result.removeFirst("https://".count)
        }

        if components.path == "/" && components.query == nil && result.hasSuffix("/") {
            result.removeLast()
        }

        return result.isEmpty ? nil : result
    }

    func record(_ url: URL) {
        guard let compact = Self.compactString(for: url) else { return }
        if let existingIndex = entries.firstIndex(where: { $0.caseInsensitiveCompare(compact) == .orderedSame }) {
            if existingIndex == 0 && entries[0] == compact {
                return
            }
            entries.remove(at: existingIndex)
        }
        entries.insert(compact, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    func suggestion(for input: String) -> String? {
        guard !input.isEmpty else { return nil }
        let lowerInput = input.lowercased()
        let hasScheme = lowerInput.hasPrefix("http://") || lowerInput.hasPrefix("https://")
        let hasWWW = lowerInput.hasPrefix("www.") || lowerInput.hasPrefix("http://www.") || lowerInput.hasPrefix("https://www.")
        let hasQuery = lowerInput.contains("?")

        func matchCandidate(from entry: String) -> String? {
            if hasScheme {
                let fullEntry = entry.hasPrefix("http://") ? entry : "https://" + entry
                if fullEntry.lowercased().hasPrefix(lowerInput) {
                    return fullEntry
                }
                return nil
            }

            let strippedEntry: String
            if entry.hasPrefix("http://") {
                strippedEntry = String(entry.dropFirst("http://".count))
            } else {
                strippedEntry = entry
            }

            if strippedEntry.lowercased().hasPrefix(lowerInput) {
                return strippedEntry
            }

            if !hasWWW && strippedEntry.lowercased().hasPrefix("www.") {
                let withoutWWW = String(strippedEntry.dropFirst(4))
                if withoutWWW.lowercased().hasPrefix(lowerInput) {
                    return withoutWWW
                }
            }

            return nil
        }

        if !hasQuery {
            for entry in entries where !entry.contains("?") {
                if let match = matchCandidate(from: entry), match.count > input.count {
                    return match
                }
            }
        }

        for entry in entries {
            if let match = matchCandidate(from: entry), match.count > input.count {
                return match
            }
        }

        return nil
    }

    private func load() {
        guard let compressed = defaults.data(forKey: storageKey) else { return }
        let rawData: Data
        if let decompressed = try? (compressed as NSData).decompressed(using: .lzfse) as Data {
            rawData = decompressed
        } else {
            rawData = compressed
        }
        guard let text = String(data: rawData, encoding: .utf8), !text.isEmpty else { return }
        entries = text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func save() {
        let joined = entries.joined(separator: "\n")
        guard let rawData = joined.data(using: .utf8) else { return }
        let stored = (try? (rawData as NSData).compressed(using: .lzfse) as Data) ?? rawData
        defaults.set(stored, forKey: storageKey)
    }
}

class Document: NSDocument, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, NSToolbarDelegate, NSTextFieldDelegate {
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

    private static let windowFrameAutosaveKey = "MonochromeWindow"
    private static let statusBarDefaultsKey = "ShowStatusBar"
    private static let statusBarHeight: CGFloat = 22
    private static let pageSizeScript = """
    (function() {
        function entryBytes(e) {
            if (!e) return 0;
            if (e.transferSize && e.transferSize > 0) return e.transferSize;
            if (e.encodedBodySize && e.encodedBodySize > 0) return e.encodedBodySize;
            if (e.decodedBodySize && e.decodedBodySize > 0) return e.decodedBodySize;
            return 0;
        }
        var navEntries = (window.performance && performance.getEntriesByType) ? performance.getEntriesByType('navigation') : [];
        var navBytes = 0;
        for (var i = 0; i < navEntries.length; i++) {
            navBytes += entryBytes(navEntries[i]);
        }
        var domBytes = 0;
        if (document.documentElement && document.documentElement.outerHTML) {
            domBytes = new TextEncoder().encode(document.documentElement.outerHTML).length;
        }
        var total = Math.max(navBytes, domBytes);
        var resEntries = (window.performance && performance.getEntriesByType) ? performance.getEntriesByType('resource') : [];
        for (var j = 0; j < resEntries.length; j++) {
            total += entryBytes(resEntries[j]);
        }
        return total;
    })();
    """

    private var observations: [NSKeyValueObservation] = []
    private var lastCommandWasDelete = false
    private var isAutocompleting = false
    private var isWindowFrameRestored = false
    private var isStatusBarVisible = defaults.bool(forKey: Document.statusBarDefaultsKey)
    private var statusBarView: NSView?
    private var statusPageSizeLabel: NSTextField?
    private var statusSizeLabel: NSTextField?
    private var webViewBottomConstraint: NSLayoutConstraint?
    private var statusSizeTimer: Timer?
    private var hasCommittedNavigation = false
    private var currentPageBytes: Int64 = 0

    var homeURL: URL {
        let homepage = defaults.string(forKey: SearchProvider.homepageKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let url = URL(string: homepage), !homepage.isEmpty {
            return url
        }
        return URL(string: SearchProvider.defaultHomepage)!
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
            if frame.origin.y < screen.visibleFrame.minY {
                frame.origin.y = max(screen.frame.minY, min(screen.visibleFrame.minY, screen.visibleFrame.maxY - frame.size.height))
            }
        }
        window.setFrame(frame, display: true, animate: animate)
        window.saveFrame(usingName: Self.windowFrameAutosaveKey)
        updateStatusBarSize(for: window)
    }

    func windowDidMove(_ notification: Notification) {
        guard isWindowFrameRestored else { return }
        (notification.object as? NSWindow ?? mainWindow)?.saveFrame(usingName: Self.windowFrameAutosaveKey)
    }

    func windowDidResize(_ notification: Notification) {
        let window = notification.object as? NSWindow ?? mainWindow
        updateStatusBarSize(for: window)
        guard isWindowFrameRestored else { return }
        window?.saveFrame(usingName: Self.windowFrameAutosaveKey)
    }

    func windowWillClose(_ notification: Notification) {
        statusSizeTimer?.invalidate()
        statusSizeTimer = nil
        guard isWindowFrameRestored else { return }
        (notification.object as? NSWindow ?? mainWindow)?.saveFrame(usingName: Self.windowFrameAutosaveKey)
    }

    @IBAction func toggleStatusBar(_ sender: Any?) {
        isStatusBarVisible.toggle()
        defaults.set(isStatusBarVisible, forKey: Self.statusBarDefaultsKey)
        statusBarView?.isHidden = !isStatusBarVisible
        webViewBottomConstraint?.constant = isStatusBarVisible ? -Self.statusBarHeight : 0
        if isStatusBarVisible {
            updateStatusBarSize()
            refreshPageSize()
        }
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
        let searchEngine = defaults.string(forKey: SearchProvider.searchEngineKey) ?? SearchProvider.defaultSearchEngine
        let rawInput = (textField?.currentEditor()?.string ?? textField?.stringValue)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let address = rawInput, !address.isEmpty else {
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
        BrowsingHistory.shared.record(targetURL)
        webView.load(URLRequest(url: targetURL))
        mainWindow?.makeFirstResponder(webView)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
           commandSelector == #selector(NSResponder.deleteForward(_:)) ||
           commandSelector == #selector(NSResponder.deleteWordBackward(_:)) ||
           commandSelector == #selector(NSResponder.deleteToBeginningOfLine(_:)) {
            lastCommandWasDelete = true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        defer { lastCommandWasDelete = false }
        guard !isAutocompleting,
              !lastCommandWasDelete,
              let editor = obj.userInfo?["NSFieldEditor"] as? NSTextView,
              !editor.hasMarkedText() else {
            return
        }

        let currentText = editor.string
        let nsCurrent = currentText as NSString
        let selection = editor.selectedRange()
        guard selection.location == nsCurrent.length,
              selection.length == 0,
              nsCurrent.length > 0 else {
            return
        }

        guard let suggestion = BrowsingHistory.shared.suggestion(for: currentText) else {
            return
        }

        let nsSuggestion = suggestion as NSString
        guard nsSuggestion.length > nsCurrent.length else { return }

        let suffix = nsSuggestion.substring(from: nsCurrent.length)
        isAutocompleting = true
        editor.replaceCharacters(in: NSRange(location: nsCurrent.length, length: 0), with: suffix)
        editor.selectedRange = NSRange(location: nsCurrent.length, length: (suffix as NSString).length)
        isAutocompleting = false
    }

    private func updateLoadingState(isLoading: Bool) {
        if isLoading {
            reload?.image = toolbarSymbol("xmark", fallback: NSImage.stopProgressTemplateName, description: "Stop")
            loading?.usesThreadedAnimation = true
            loading?.startAnimation(reload)
            startPageSizeTracking()
        } else {
            reload?.image = toolbarSymbol("arrow.clockwise", fallback: NSImage.refreshTemplateName, description: "Reload")
            loading?.stopAnimation(reload)
            stopPageSizeTracking()
        }
    }

    private func formatByteSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", max(0.1, kb))
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private func updateStatusBarPageSize(bytes: Int64) {
        currentPageBytes = max(currentPageBytes, bytes)
        statusPageSizeLabel?.stringValue = formatByteSize(currentPageBytes)
    }

    private func refreshPageSize() {
        guard hasCommittedNavigation, let webView = webView else { return }
        webView.evaluateJavaScript(Self.pageSizeScript) { [weak self] result, _ in
            guard let self = self else { return }
            if let number = result as? NSNumber {
                self.updateStatusBarPageSize(bytes: number.int64Value)
            }
        }
    }

    private func startPageSizeTracking() {
        guard statusSizeTimer == nil else { return }
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.refreshPageSize()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusSizeTimer = timer
    }

    private func stopPageSizeTracking() {
        statusSizeTimer?.invalidate()
        statusSizeTimer = nil
        refreshPageSize()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshPageSize()
        }
    }

    private func updateStatusBarSize(for window: NSWindow? = nil) {
        guard let targetWindow = window ?? mainWindow ?? windowControllers.first?.window else { return }
        let width = Int(round(targetWindow.frame.width))
        let height = Int(round(targetWindow.frame.height))
        statusSizeLabel?.stringValue = "\(width) × \(height) px"
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
        case #selector(toggleStatusBar(_:)):
            if let menuItem = item as? NSMenuItem {
                menuItem.title = isStatusBarVisible ? "Hide Status Bar" : "Show Status Bar"
            }
            return true
        default:
            return super.validateUserInterfaceItem(item)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hasCommittedNavigation = false
        currentPageBytes = 0
        statusPageSizeLabel?.stringValue = formatByteSize(0)
        updateLoadingState(isLoading: true)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        hasCommittedNavigation = true
        updateLoadingState(isLoading: true)
        updateNavigationState()
        refreshPageSize()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            BrowsingHistory.shared.record(url)
        }
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
        addressField.delegate = self
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

    private func setupStatusBar(for window: NSWindow) {
        guard let contentView = window.contentView else { return }

        for constraint in contentView.constraints where
            (constraint.firstItem as? NSView == webView && constraint.firstAttribute == .bottom) ||
            (constraint.secondItem as? NSView == webView && constraint.secondAttribute == .bottom) {
            constraint.isActive = false
        }

        let bottomConstraint = webView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: isStatusBarVisible ? -Self.statusBarHeight : 0
        )
        bottomConstraint.isActive = true
        webViewBottomConstraint = bottomConstraint

        let bar = NSVisualEffectView()
        bar.material = .windowBackground
        bar.blendingMode = .withinWindow
        bar.state = .followsWindowActiveState
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isHidden = !isStatusBarVisible

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let pageSizeLabel = NSTextField(labelWithString: "0 KB")
        pageSizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        pageSizeLabel.textColor = .secondaryLabelColor
        pageSizeLabel.translatesAutoresizingMaskIntoConstraints = false

        let sizeLabel = NSTextField(labelWithString: "")
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.alignment = .right
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(separator)
        bar.addSubview(pageSizeLabel)
        bar.addSubview(sizeLabel)
        contentView.addSubview(bar)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.statusBarHeight),

            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.topAnchor.constraint(equalTo: bar.topAnchor),

            pageSizeLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            pageSizeLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            sizeLabel.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            sizeLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: pageSizeLabel.trailingAnchor, constant: 8)
        ])

        statusBarView = bar
        statusPageSizeLabel = pageSizeLabel
        statusSizeLabel = sizeLabel
        updateStatusBarSize(for: window)
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

        windowController.shouldCascadeWindows = false
        if let window = windowController.window ?? mainWindow {
            setupToolbar(for: window)
            setupStatusBar(for: window)
            if !window.setFrameUsingName(Self.windowFrameAutosaveKey) {
                resizeWindow(width: 375, height: 667, animate: false)
            }
            window.setFrameAutosaveName(Self.windowFrameAutosaveKey)
            window.delegate = self
            isWindowFrameRestored = true
            updateStatusBarSize(for: window)
        }
        updateNavigationState()

        observations = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                if let url = webView.url {
                    BrowsingHistory.shared.record(url)
                }
                self?.updateNavigationState()
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                self?.updateLoadingState(isLoading: webView.isLoading)
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                self?.refreshPageSize()
            }
        ]

        let requested = URLRequest(url: homeURL)
        webView.load(requested)
    }

    override init() {
        super.init()
    }

    deinit {
        statusSizeTimer?.invalidate()
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

