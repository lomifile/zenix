-- Transparent background: ghostty runs at background-opacity = 0.85 over the
-- compositor's blur, so the editor, the sidebars and the floats all hand their
-- background back to the terminal and read through to the desktop.
require("xcode-zenix").setup({ transparent = true })
require("xcode-zenix").load()
