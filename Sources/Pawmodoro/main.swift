import AppKit

// Menu-bar-only background utility: no Dock icon, no main window. `.accessory`
// is the programmatic equivalent of LSUIElement, so no Info.plist is required
// for the walking skeleton. A signed .app bundle comes in the packaging slice.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
