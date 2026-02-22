import AppKit

protocol KeyboardShortcutEditable {}

extension KeyboardShortcutEditable where Self: NSTextField {
    func handleEditShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command || modifiers == .control,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }
        let selector: Selector?
        switch key {
        case "c":
            selector = #selector(NSText.copy(_:))
        case "v":
            selector = #selector(NSText.paste(_:))
        case "x":
            selector = #selector(NSText.cut(_:))
        case "a":
            selector = #selector(NSText.selectAll(_:))
        default:
            selector = nil
        }
        guard let selector else { return false }
        return NSApp.sendAction(selector, to: nil, from: self)
    }
}

final class ShortcutTextField: NSTextField, KeyboardShortcutEditable {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleEditShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class ShortcutSecureTextField: NSSecureTextField, KeyboardShortcutEditable {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleEditShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
