//
//  Preferences.swift
//  Monochrome
//
//  Created by lucian on 12/8/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

class Preferences: NSWindowController, NSTextFieldDelegate {
    private var radioButtons: [SearchProvider: NSButton] = [:]
    private var rootStack: NSStackView!
    private var customFieldsStack: NSStackView!
    private var homepageField: NSTextField!
    private var searchEngineField: NSTextField!

    override var windowNibName: NSNib.Name? {
        return NSNib.Name("Preferences")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        setupUI()
        loadCurrentPreferences(animate: false)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if isWindowLoaded {
            loadCurrentPreferences(animate: false)
        }
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let radioStack = NSStackView()
        radioStack.orientation = .vertical
        radioStack.alignment = .leading
        radioStack.spacing = 10
        radioStack.translatesAutoresizingMaskIntoConstraints = false

        for (index, provider) in SearchProvider.allCases.enumerated() {
            let button = NSButton(radioButtonWithTitle: provider.title, target: self, action: #selector(providerChanged(_:)))
            button.tag = index
            radioStack.addArrangedSubview(button)
            radioButtons[provider] = button
        }

        let homepageLabel = NSTextField(labelWithString: "Homepage:")
        homepageField = makeTextField(placeholder: SearchProvider.defaultHomepage)

        let searchEngineLabel = NSTextField(labelWithString: "Search Engine:")
        searchEngineField = makeTextField(placeholder: SearchProvider.defaultSearchEngine)

        customFieldsStack = NSStackView(views: [
            homepageLabel,
            homepageField,
            searchEngineLabel,
            searchEngineField
        ])
        customFieldsStack.orientation = .vertical
        customFieldsStack.alignment = .leading
        customFieldsStack.spacing = 6
        customFieldsStack.setCustomSpacing(10, after: homepageField)
        customFieldsStack.translatesAutoresizingMaskIntoConstraints = false

        rootStack = NSStackView(views: [radioStack, customFieldsStack])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 14
        rootStack.detachesHiddenViews = true
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            homepageField.widthAnchor.constraint(equalToConstant: 280),
            searchEngineField.widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    private func makeTextField(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private func currentProvider() -> SearchProvider {
        let raw = defaults.string(forKey: SearchProvider.defaultsKey) ?? SearchProvider.duckDuckGo.rawValue
        return SearchProvider(rawValue: raw) ?? .duckDuckGo
    }

    private func loadCurrentPreferences(animate: Bool) {
        let provider = currentProvider()
        for (item, button) in radioButtons {
            button.state = (item == provider) ? .on : .off
        }

        let customHome = defaults.string(forKey: SearchProvider.customHomepageKey) ?? SearchProvider.defaultHomepage
        let customSearch = defaults.string(forKey: SearchProvider.customSearchEngineKey) ?? SearchProvider.defaultSearchEngine
        homepageField.stringValue = customHome
        searchEngineField.stringValue = customSearch

        applyProvider(provider, animate: animate)
    }

    @objc private func providerChanged(_ sender: NSButton) {
        let allProviders = SearchProvider.allCases
        guard sender.tag >= 0, sender.tag < allProviders.count else { return }
        let selected = allProviders[sender.tag]
        for (item, button) in radioButtons {
            button.state = (item == selected) ? .on : .off
        }
        defaults.set(selected.rawValue, forKey: SearchProvider.defaultsKey)
        applyProvider(selected, animate: true)
    }

    private func applyProvider(_ provider: SearchProvider, animate: Bool) {
        if let presetHome = provider.homepage, let presetSearch = provider.searchEngine {
            defaults.set(presetHome, forKey: SearchProvider.homepageKey)
            defaults.set(presetSearch, forKey: SearchProvider.searchEngineKey)
            customFieldsStack.isHidden = true
        } else {
            let customHome = homepageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let customSearch = searchEngineField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(customHome.isEmpty ? SearchProvider.defaultHomepage : customHome, forKey: SearchProvider.homepageKey)
            defaults.set(customSearch.isEmpty ? SearchProvider.defaultSearchEngine : customSearch, forKey: SearchProvider.searchEngineKey)
            customFieldsStack.isHidden = false
        }

        resizeWindowToFitContent(animate: animate)

        if provider == .custom {
            window?.makeFirstResponder(homepageField)
        }
    }

    private func resizeWindowToFitContent(animate: Bool) {
        guard let window = window else { return }
        rootStack.layoutSubtreeIfNeeded()
        let fittingSize = rootStack.fittingSize
        let contentSize = NSSize(width: 320, height: fittingSize.height + 40)
        let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size

        var frame = window.frame
        frame.origin.y += frame.size.height - targetFrameSize.height
        frame.size = targetFrameSize
        window.setFrame(frame, display: true, animate: animate)
    }

    func controlTextDidChange(_ obj: Notification) {
        saveCustomFields()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        saveCustomFields()
    }

    private func saveCustomFields() {
        let customHome = homepageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let customSearch = searchEngineField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(customHome, forKey: SearchProvider.customHomepageKey)
        defaults.set(customSearch, forKey: SearchProvider.customSearchEngineKey)

        if currentProvider() == .custom {
            defaults.set(customHome.isEmpty ? SearchProvider.defaultHomepage : customHome, forKey: SearchProvider.homepageKey)
            defaults.set(customSearch.isEmpty ? SearchProvider.defaultSearchEngine : customSearch, forKey: SearchProvider.searchEngineKey)
        }
    }
}
