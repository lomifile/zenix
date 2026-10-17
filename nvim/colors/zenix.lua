-- Opaque: ghostty runs at background-opacity = 1, so the editor, the sidebars
-- and the floats paint their own background from the palette rather than
-- handing it back to the terminal.
require("zenix").setup({ transparent = false })
require("zenix").load()
