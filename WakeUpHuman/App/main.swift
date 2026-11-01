import AppKit

#if DEBUG
    VolumeProbe.runIfRequested()
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
