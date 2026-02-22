import AppKit

extension SettingsWindowController {
    func refreshAISettings() {
        aiSettings = getAISettings()
        isRefreshingAISettings = true
        aiEnabledCheckbox.state = aiSettings.isEnabled ? .on : .off
        aiBaseURLField.stringValue = aiSettings.baseURL
        aiTokenField.stringValue = aiSettings.token
        aiTokenRevealField.stringValue = aiSettings.token
        aiModelField.stringValue = aiSettings.model
        hideTokenReveal()
        updateAIFieldsEnabledState()
        isRefreshingAISettings = false
    }

    func updateAIFieldsEnabledState() {
        let isEnabled = aiEnabledCheckbox.state == .on
        aiBaseURLField.isEnabled = isEnabled
        aiTokenField.isEnabled = isEnabled
        aiTokenRevealButton.isEnabled = isEnabled
        aiModelField.isEnabled = isEnabled
    }

    @objc func toggleAISettingsEnabled() {
        guard isRefreshingAISettings == false else { return }
        persistAISettingsFromControls()
    }

    func persistAISettingsFromControls() {
        guard isRefreshingAISettings == false else { return }
        let next = AISettings(
            isEnabled: aiEnabledCheckbox.state == .on,
            baseURL: aiBaseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            token: aiTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            model: aiModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        aiSettings = next
        updateAIFieldsEnabledState()
        setAISettings(next)
    }

    @objc func handleTokenRevealPress(_ sender: NSButton) {
        guard aiEnabledCheckbox.state == .on else { return }
        switch NSApp.currentEvent?.type {
        case .leftMouseDown:
            showTokenReveal()
        case .leftMouseUp:
            hideTokenReveal()
        default:
            break
        }
    }

    func showTokenReveal() {
        aiTokenRevealField.stringValue = aiTokenField.stringValue
        aiTokenField.isHidden = true
        aiTokenRevealField.isHidden = false
    }

    func hideTokenReveal() {
        aiTokenRevealField.isHidden = true
        aiTokenField.isHidden = false
    }
}
