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
        aiUsePreviousResponseIDCheckbox.state = aiSettings.usePreviousResponseID ? .on : .off
        aiTimeoutField.stringValue = formatAITimeout(aiSettings.timeoutSeconds)
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
        aiUsePreviousResponseIDCheckbox.isEnabled = isEnabled
        aiTimeoutField.isEnabled = isEnabled
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
            model: aiModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            usePreviousResponseID: aiUsePreviousResponseIDCheckbox.state == .on,
            timeoutSeconds: parseAITimeout(aiTimeoutField.stringValue)
        )
        aiSettings = next
        aiTimeoutField.stringValue = formatAITimeout(next.timeoutSeconds)
        updateAIFieldsEnabledState()
        setAISettings(next)
    }

    func parseAITimeout(_ value: String) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(trimmed), parsed > 0 else {
            return 30
        }
        return parsed
    }

    func formatAITimeout(_ value: Double) -> String {
        let rounded = value.rounded(.towardZero)
        if abs(value - rounded) < 0.000_1 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
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
