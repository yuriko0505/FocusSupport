import AppKit

extension SettingsWindowController {
    func refreshAISettings() {
        aiSettings = getAISettings()
        isRefreshingAISettings = true
        aiEnabledCheckbox.state = aiSettings.isEnabled ? .on : .off
        aiBaseURLField.stringValue = aiSettings.baseURL
        aiTokenField.stringValue = aiSettings.token
        aiModelField.stringValue = aiSettings.model
        updateAIFieldsEnabledState()
        isRefreshingAISettings = false
    }

    func updateAIFieldsEnabledState() {
        let isEnabled = aiEnabledCheckbox.state == .on
        aiBaseURLField.isEnabled = isEnabled
        aiTokenField.isEnabled = isEnabled
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
}
