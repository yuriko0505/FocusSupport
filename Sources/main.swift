import AppKit

let app = NSApplication.shared
let delegate = FocusSupportApp()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
