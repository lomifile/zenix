local M = {}

M.options = {
  transparent = false,
  italic = {
    comments = true,
    keywords = true,
    types = true,
    parameters = true,
    functions = false,
    strings = false,
  },
}

local italic_groups = {
  comments = {
    "Comment", "SpecialComment", "Todo",
    "@comment", "@comment.error", "@comment.warning", "@comment.todo", "@comment.note",
    "@markup.quote", "LspCodeLens", "DiagnosticUnnecessary",
  },
  keywords = {
    "Statement", "PreProc",
    "@variable.builtin", "@lsp.type.keyword", "@lsp.type.macro", "@function.macro",
    "@constant.macro", "@keyword.directive", "@type.qualifier",
  },
  types = {
    "Type", "Typedef",
    "@type", "@type.builtin", "@type.definition", "@constructor",
    "@module", "@namespace", "@attribute",
    "@lsp.type.class", "@lsp.type.enum", "@lsp.type.interface", "@lsp.type.struct",
    "@lsp.type.type", "@lsp.type.typeParameter", "@lsp.type.namespace",
    "@lsp.typemod.class.declaration", "@lsp.typemod.type.defaultLibrary",
  },
  parameters = {
    "@variable.parameter", "@lsp.type.parameter", "LspSignatureActiveParameter",
  },
  functions = {
    "Function",
    "@function", "@function.call", "@function.builtin",
    "@function.method", "@function.method.call",
    "@lsp.type.function", "@lsp.type.method",
    "@lsp.typemod.function.declaration", "@lsp.typemod.method.declaration",
    "@lsp.typemod.function.defaultLibrary",
  },
  strings = {
    "String", "Character",
    "@string", "@string.regexp", "@string.escape", "@string.special",
  },
}

local function apply_italics(groups, wanted)
  for flag, names in pairs(italic_groups) do
    if wanted[flag] then
      for _, name in ipairs(names) do
        local spec = groups[name]
        if spec and not spec.link and next(spec) ~= nil then
          spec.italic = true
        end
      end
    end
  end
end

local function completion_groups(c, float_bg, menu_bg)
  local kinds = {
    [c.purple] = { "Function", "Method", "Constructor" },
    [c.teal] = { "Variable", "Field", "Property" },
    [c.lilac] = { "Class", "Interface", "Struct", "Enum", "EnumMember", "Module", "TypeParameter" },
    [c.pink] = { "Keyword", "Operator" },
    [c.sand] = { "Constant", "Value", "Unit" },
    [c.orange] = { "Snippet", "Event" },
    [c.cyan] = { "File", "Folder" },
    [c.mint] = { "Color" },
    [c.fg_dim] = { "Text", "Reference" },
  }

  -- The popup borders read as one family: menu, documentation, signature help
  -- and the LSP hover that borrows BlinkCmpDoc* all draw the same white
  -- hairline, so the rounded corners stay visible against the float body.
  local border = c.fg

  local out = {
    BlinkCmpMenu = { fg = c.fg, bg = menu_bg },
    BlinkCmpMenuBorder = { fg = border, bg = menu_bg },
    BlinkCmpMenuSelection = { bg = c.bg_sel },
    BlinkCmpScrollBarThumb = { bg = c.bg_sel },
    BlinkCmpScrollBarGutter = { bg = menu_bg },

    BlinkCmpLabel = { fg = c.fg_dim },
    BlinkCmpLabelMatch = { fg = c.cyan, bold = true },
    BlinkCmpLabelDetail = { fg = c.gutter },
    BlinkCmpLabelDescription = { fg = c.gutter },
    BlinkCmpLabelDeprecated = { fg = c.gutter, strikethrough = true },
    BlinkCmpSource = { fg = c.gutter },
    BlinkCmpGhostText = { fg = c.gutter, italic = true },
    BlinkCmpKindName = { fg = c.gutter },

    BlinkCmpDoc = { fg = c.fg_dim, bg = float_bg },
    BlinkCmpDocBorder = { fg = border, bg = float_bg },
    BlinkCmpDocSeparator = { fg = c.bg_panel, bg = float_bg },
    BlinkCmpDocCursorLine = { bg = c.bg_sel },

    BlinkCmpSignatureHelp = { fg = c.fg_dim, bg = float_bg },
    BlinkCmpSignatureHelpBorder = { fg = border, bg = float_bg },
    BlinkCmpSignatureHelpActiveParameter = { fg = c.orange, bold = true },

    BlinkCmpKind = { fg = c.comment },
  }

  for colour, names in pairs(kinds) do
    for _, name in ipairs(names) do
      out["BlinkCmpKind" .. name] = { fg = colour }
      out["CmpItemKind" .. name] = { fg = colour }
    end
  end

  return out
end

local function bufferline_groups(c, editor_bg)
  local states = {
    { suffix = "", bg = c.bg_tab, fg = c.gutter },
    { suffix = "Visible", bg = c.bg_tab, fg = c.comment },
    { suffix = "Selected", bg = editor_bg, fg = c.fg },
  }

  local tinted = {
    Modified = c.orange,
    Duplicate = c.gutter,
    Pick = c.pink,
    Numbers = c.comment,
    Diagnostic = c.comment,
    Hint = c.teal,
    Info = c.cyan,
    Warning = c.orange,
    Error = c.salmon,
    HintDiagnostic = c.teal,
    InfoDiagnostic = c.cyan,
    WarningDiagnostic = c.orange,
    ErrorDiagnostic = c.salmon,
  }

  local out = {
    BufferLineFill = { bg = c.bg_chrome },
    BufferLineOffsetSeparator = { fg = c.chrome_line, bg = c.bg_chrome },
    BufferLineTruncMarker = { fg = c.gutter, bg = c.bg_chrome },
    BufferLineGroupSeparator = { fg = c.gutter, bg = c.bg_chrome },
    BufferLineGroupLabel = { fg = c.bg_chrome, bg = c.comment },
    BufferLineTab = { fg = c.comment, bg = c.bg_tab },
    BufferLineTabSelected = { fg = c.fg, bg = editor_bg, bold = true },
    BufferLineTabSeparator = { fg = c.chrome_line, bg = c.bg_tab },
    BufferLineTabSeparatorSelected = { fg = c.chrome_line, bg = editor_bg },
    BufferLineTabClose = { fg = c.comment, bg = c.bg_chrome },
  }

  for _, state in ipairs(states) do
    local bg = state.bg
    local base = state.suffix == "" and "Background" or ("Buffer" .. state.suffix)

    out["BufferLine" .. base] = { fg = state.fg, bg = bg, bold = state.suffix == "Selected" }
    out["BufferLineCloseButton" .. state.suffix] = { fg = state.fg, bg = bg }
    out["BufferLineSeparator" .. state.suffix] = { fg = c.chrome_line, bg = bg }
    out["BufferLineIndicator" .. state.suffix] = { fg = bg, bg = bg }
    out["BufferLineDevIconDefault" .. state.suffix] = { fg = state.fg, bg = bg }

    for name, colour in pairs(tinted) do
      out["BufferLine" .. name .. state.suffix] = { fg = colour, bg = bg }
    end
  end

  out.BufferLineIndicatorSelected = { fg = c.cyan, bg = editor_bg }
  out.BufferLineDuplicateSelected = { fg = c.comment, bg = editor_bg }

  return out
end

local function build(c, opts)
  local editor_bg = opts.transparent and "NONE" or c.bg
  local float_bg = opts.transparent and "NONE" or c.bg_float

  local sidebar_bg = opts.transparent and "NONE" or c.bg_chrome

  local declaration = c.cyan
  local project_type = c.mint
  local library_type = c.lilac
  local project_ident = c.teal
  local library_ident = c.purple
  local ident_def = c.steel

  return {
    Normal = { fg = c.fg, bg = editor_bg },
    NormalNC = { fg = c.fg, bg = editor_bg },
    NormalFloat = { fg = c.fg, bg = float_bg },
    FloatBorder = { fg = c.fg, bg = float_bg },
    FloatTitle = { fg = c.fg, bg = float_bg, bold = true },
    Cursor = { fg = c.bg, bg = c.fg },
    lCursor = { fg = c.bg, bg = c.fg },
    CursorLine = { bg = c.bg_line },
    CursorColumn = { bg = c.bg_line },
    ColorColumn = { bg = c.bg_line },
    CursorLineNr = { fg = c.fg, bg = c.bg_line },
    LineNr = { fg = c.gutter },
    LineNrAbove = { fg = c.gutter },
    LineNrBelow = { fg = c.gutter },
    SignColumn = { fg = c.gutter, bg = editor_bg },
    FoldColumn = { fg = c.gutter, bg = editor_bg },
    Folded = { fg = c.gutter, bg = c.bg_panel },
    EndOfBuffer = { fg = editor_bg },
    NonText = { fg = c.gutter },
    Whitespace = { fg = c.bg_sel },
    SpecialKey = { fg = c.gutter },
    Conceal = { fg = c.comment },
    MatchParen = { fg = c.fg, bg = c.bg_sel, bold = true },

    Visual = { bg = c.bg_sel },
    VisualNOS = { bg = c.bg_sel },
    Search = { fg = c.fg, bg = c.bg_sel },
    IncSearch = { fg = c.bg, bg = c.highlight_yellow },
    CurSearch = { fg = c.bg, bg = c.highlight_yellow },
    Substitute = { fg = c.bg, bg = c.orange },
    QuickFixLine = { fg = c.fg, bg = c.select_blue },
    WildMenu = { fg = c.fg, bg = c.select_blue },

    Pmenu = { fg = c.fg, bg = c.bg_panel },
    PmenuSel = { fg = c.fg, bg = c.select_blue },
    PmenuSbar = { bg = c.bg_panel },
    PmenuThumb = { bg = c.bg_sel },
    PmenuKind = { fg = c.lilac, bg = c.bg_panel },
    PmenuKindSel = { fg = c.fg, bg = c.select_blue },
    PmenuExtra = { fg = c.comment, bg = c.bg_panel },
    PmenuExtraSel = { fg = c.fg, bg = c.select_blue },

    StatusLine = { fg = c.fg_dim, bg = c.bg_chrome },
    StatusLineNC = { fg = c.gutter, bg = c.bg_chrome },
    WinBar = { fg = c.comment, bg = c.bg_tab },
    WinBarNC = { fg = c.gutter, bg = c.bg_tab },
    TabLine = { fg = c.comment, bg = c.bg_chrome },
    TabLineSel = { fg = c.fg, bg = c.bg_chrome },
    TabLineFill = { bg = c.bg_chrome },

    -- The two chrome rows above the editor: a title bar in the tabline and
    -- buffer chips in the winbar. Named groups rather than colours inlined in
    -- the lualine config, so `:hi ZenixTab...` tells you what a bar is made of
    -- and a palette change reaches both at once.
    ZenixTitle = { fg = c.fg, bg = c.bg_chrome },
    ZenixTitleDim = { fg = c.comment, bg = c.bg_chrome },
    ZenixTitleSep = { fg = c.gutter, bg = c.bg_chrome },
    ZenixTitleDot = { fg = c.teal, bg = c.bg_chrome },

    -- The active chip carries the editor background so it reads as the top
    -- edge of the buffer below it, the way the mockup's chip does.
    ZenixTabFill = { bg = c.bg_tab },
    ZenixTabActive = { fg = c.fg, bg = editor_bg },
    ZenixTabInactive = { fg = c.comment, bg = c.bg_tab },
    ZenixTabDot = { fg = c.teal, bg = editor_bg },
    ZenixTabDotModified = { fg = c.orange, bg = editor_bg },
    ZenixTabDotInactive = { fg = c.gutter, bg = c.bg_tab },
    ZenixExplorer = { fg = c.comment, bg = sidebar_bg },

    -- Statusline pieces. diff_add is the palette's green-tinted panel, which
    -- is what makes the mode block read as a tinted chip rather than a slab.
    ZenixMode = { fg = c.teal, bg = c.diff_add, bold = true },
    ZenixLspOn = { fg = c.teal, bg = c.bg_chrome },
    ZenixLspOff = { fg = c.gutter, bg = c.bg_chrome },
    WinSeparator = { fg = c.chrome_line, bg = editor_bg },
    VertSplit = { fg = c.chrome_line, bg = editor_bg },

    MsgArea = { fg = c.fg },
    ModeMsg = { fg = c.comment },
    MoreMsg = { fg = c.pink },
    Question = { fg = c.pink },
    ErrorMsg = { fg = c.salmon },
    WarningMsg = { fg = c.orange },
    Title = { fg = c.fg, bold = true },
    Directory = { fg = c.cyan },

    Comment = { fg = c.comment },
    SpecialComment = { fg = c.fg_dim },
    Todo = { fg = c.fg_dim, bold = true },
    Error = { fg = c.bg, bg = c.salmon },
    Ignore = { fg = c.gutter },
    Underlined = { fg = c.cyan, underline = true },

    Statement = { fg = c.pink, bold = true },
    Keyword = { link = "Statement" },
    Conditional = { link = "Statement" },
    Repeat = { link = "Statement" },
    Label = { link = "Statement" },
    Exception = { link = "Statement" },
    Include = { link = "Statement" },
    Boolean = { link = "Statement" },
    StorageClass = { link = "Statement" },
    Structure = { link = "Statement" },
    Operator = { fg = c.fg },
    Delimiter = { fg = c.fg_dim },

    String = { fg = c.salmon },
    Character = { fg = c.sand },
    Number = { fg = c.sand },
    Float = { link = "Number" },
    Constant = { fg = library_ident },

    PreProc = { fg = c.orange },
    Define = { link = "PreProc" },
    Macro = { link = "PreProc" },
    PreCondit = { link = "PreProc" },

    Type = { fg = library_type },
    Typedef = { fg = declaration },
    Identifier = { fg = project_ident },
    Function = { fg = library_ident },
    Special = { fg = c.teal },
    SpecialChar = { fg = c.teal },
    Tag = { fg = c.teal },
    Debug = { fg = c.orange },

    DiffAdd = { fg = c.mint, bg = c.diff_add },
    DiffChange = { fg = c.orange },
    DiffDelete = { fg = c.salmon, bg = c.diff_delete },
    DiffText = { fg = c.orange, bg = c.diff_text },
    Added = { fg = c.mint },
    Changed = { fg = c.orange },
    Removed = { fg = c.salmon },

    DiagnosticError = { fg = c.salmon },
    DiagnosticWarn = { fg = c.orange },
    DiagnosticInfo = { fg = c.cyan },
    DiagnosticHint = { fg = c.teal },
    DiagnosticOk = { fg = c.mint },
    DiagnosticUnderlineError = { sp = c.salmon, undercurl = true },
    DiagnosticUnderlineWarn = { sp = c.orange, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.cyan, undercurl = true },
    DiagnosticUnderlineHint = { sp = c.teal, undercurl = true },
    DiagnosticVirtualTextError = { fg = c.salmon, bg = c.diff_delete },
    DiagnosticVirtualTextWarn = { fg = c.orange, bg = c.diff_text },
    DiagnosticVirtualTextInfo = { fg = c.cyan },
    DiagnosticVirtualTextHint = { fg = c.teal },
    DiagnosticUnnecessary = { fg = c.gutter },

    ["@comment"] = { link = "Comment" },
    ["@comment.error"] = { fg = c.salmon, bold = true },
    ["@comment.warning"] = { fg = c.orange, bold = true },
    ["@comment.todo"] = { link = "Todo" },
    ["@comment.note"] = { fg = c.cyan, bold = true },

    ["@keyword"] = { link = "Statement" },
    ["@keyword.function"] = { link = "Statement" },
    ["@keyword.operator"] = { link = "Statement" },
    ["@keyword.return"] = { link = "Statement" },
    ["@keyword.import"] = { link = "Statement" },
    ["@keyword.exception"] = { link = "Statement" },
    ["@keyword.conditional"] = { link = "Statement" },
    ["@keyword.repeat"] = { link = "Statement" },
    ["@keyword.directive"] = { link = "PreProc" },

    ["@string"] = { link = "String" },
    ["@string.regexp"] = { fg = c.teal },
    ["@string.escape"] = { fg = c.teal },
    ["@string.special"] = { fg = c.teal },
    ["@string.special.url"] = { fg = c.cyan, underline = true },
    ["@character"] = { link = "Character" },
    ["@number"] = { link = "Number" },
    ["@boolean"] = { link = "Statement" },

    ["@type"] = { fg = library_type },
    ["@type.builtin"] = { fg = library_type },
    ["@type.definition"] = { fg = declaration },
    ["@type.qualifier"] = { link = "Statement" },
    ["@attribute"] = { fg = c.orange },

    ["@function"] = { fg = project_ident },
    ["@function.call"] = { fg = library_ident },
    ["@function.builtin"] = { fg = library_ident },
    ["@function.method"] = { fg = project_ident },
    ["@function.method.call"] = { fg = library_ident },
    ["@function.macro"] = { fg = c.orange },
    ["@constructor"] = { fg = library_type },

    ["@variable"] = { fg = c.fg },
    ["@variable.builtin"] = { fg = c.pink },
    ["@variable.parameter"] = { fg = c.fg },
    ["@variable.member"] = { fg = project_ident },
    ["@property"] = { fg = project_ident },
    ["@field"] = { fg = project_ident },

    ["@constant"] = { fg = library_ident },
    ["@constant.builtin"] = { fg = library_ident },
    ["@constant.macro"] = { fg = c.orange },

    ["@module"] = { fg = library_type },
    ["@namespace"] = { fg = library_type },
    ["@label"] = { link = "Statement" },
    ["@operator"] = { fg = c.fg },
    ["@punctuation.delimiter"] = { fg = c.fg_dim },
    ["@punctuation.bracket"] = { fg = c.fg_dim },
    ["@punctuation.special"] = { fg = c.teal },
    ["@tag"] = { fg = c.pink, bold = true },
    ["@tag.builtin"] = { fg = c.pink, bold = true },
    ["@tag.attribute"] = { fg = project_ident },
    ["@tag.delimiter"] = { fg = c.fg_dim },

    ["@markup.heading"] = { fg = c.fg, bold = true },
    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.link"] = { fg = c.cyan, underline = true },
    ["@markup.link.label"] = { fg = c.teal },
    ["@markup.raw"] = { fg = c.lilac },
    ["@markup.list"] = { fg = c.teal },
    ["@markup.quote"] = { fg = c.comment },
    ["@diff.plus"] = { fg = c.mint },
    ["@diff.minus"] = { fg = c.salmon },
    ["@diff.delta"] = { fg = c.orange },

    ["@lsp.type.class"] = { fg = library_type },
    ["@lsp.type.enum"] = { fg = library_type },
    ["@lsp.type.interface"] = { fg = library_type },
    ["@lsp.type.struct"] = { fg = library_type },
    ["@lsp.type.type"] = { fg = library_type },
    ["@lsp.type.typeParameter"] = { fg = project_type },
    ["@lsp.type.enumMember"] = { fg = library_ident },
    ["@lsp.type.function"] = { fg = library_ident },
    ["@lsp.type.method"] = { fg = library_ident },
    ["@lsp.type.macro"] = { fg = c.orange },
    ["@lsp.type.namespace"] = { fg = library_type },
    ["@lsp.type.property"] = { fg = project_ident },
    ["@lsp.type.parameter"] = { fg = c.fg },
    ["@lsp.type.variable"] = { fg = c.fg },
    ["@lsp.type.keyword"] = { link = "Statement" },
    ["@lsp.type.comment"] = {},
    ["@lsp.mod.declaration"] = { fg = declaration },
    ["@lsp.mod.definition"] = { fg = declaration },
    ["@lsp.typemod.function.declaration"] = { fg = declaration },
    ["@lsp.typemod.method.declaration"] = { fg = declaration },
    ["@lsp.typemod.class.declaration"] = { fg = declaration },
    ["@lsp.typemod.variable.defaultLibrary"] = { fg = library_ident },
    ["@lsp.typemod.function.defaultLibrary"] = { fg = library_ident },
    ["@lsp.typemod.type.defaultLibrary"] = { fg = library_type },

    LazygitActiveBorder = { fg = c.cyan },
    LazygitInactiveBorder = { fg = c.fg_dim },
    LazygitSearchBorder = { fg = c.orange },
    LazygitMuted = { fg = c.comment },
    LazygitCherryPickFg = { fg = c.bg },
    LazygitCherryPickBg = { fg = c.lilac },

    LspReferenceText = { bg = c.bg_sel },
    LspReferenceRead = { bg = c.bg_sel },
    LspReferenceWrite = { bg = c.bg_sel },
    LspInlayHint = { fg = c.gutter, bg = c.bg_line },
    LspSignatureActiveParameter = { fg = c.orange, bold = true },
    LspCodeLens = { fg = c.gutter },

    GitSignsAdd = { fg = c.teal },
    GitSignsChange = { fg = c.orange },
    GitSignsDelete = { fg = c.salmon },
    GitSignsAddInline = { bg = c.diff_add },
    GitSignsDeleteInline = { bg = c.diff_delete },

    NeoTreeNormal = { fg = c.fg_dim, bg = sidebar_bg },
    NeoTreeNormalNC = { fg = c.fg_dim, bg = sidebar_bg },
    NeoTreeWinSeparator = { fg = c.chrome_line, bg = sidebar_bg },
    NeoTreeEndOfBuffer = { fg = sidebar_bg, bg = sidebar_bg },
    NeoTreeRootName = { fg = c.comment, bold = true },
    NeoTreeDirectoryName = { fg = c.fg_dim },
    NeoTreeDirectoryIcon = { fg = c.comment },
    NeoTreeFileName = { fg = c.fg_dim },
    NeoTreeFileNameOpened = { fg = c.teal },
    NeoTreeFileIcon = { fg = c.comment },
    NeoTreeIndentMarker = { fg = "#33353d" },
    NeoTreeExpander = { fg = c.comment },
    NeoTreeDotfile = { fg = c.gutter },
    NeoTreeGitAdded = { fg = c.teal },
    NeoTreeGitModified = { fg = c.orange },
    NeoTreeGitDeleted = { fg = c.salmon },
    NeoTreeGitConflict = { fg = c.salmon, bold = true },
    NeoTreeGitUntracked = { fg = c.comment },
    NeoTreeGitIgnored = { fg = c.gutter },
    NeoTreeCursorLine = { bg = c.diff_add },
    NeoTreeTitleBar = { fg = c.fg, bg = c.bg_chrome },
    NeoTreeFloatBorder = { fg = c.fg, bg = float_bg },
    NeoTreeFloatTitle = { fg = c.fg, bg = float_bg },
    NeoTreeTabActive = { fg = c.fg, bg = sidebar_bg, bold = true },
    NeoTreeTabInactive = { fg = c.gutter, bg = c.bg_chrome },
    NeoTreeTabSeparatorActive = { fg = sidebar_bg, bg = sidebar_bg },
    NeoTreeTabSeparatorInactive = { fg = c.bg_chrome, bg = c.bg_chrome },

    TelescopeNormal = { fg = c.fg_dim, bg = float_bg },
    TelescopeBorder = { fg = c.fg, bg = float_bg },
    TelescopeTitle = { fg = c.fg, bg = float_bg, bold = true },
    TelescopePromptNormal = { fg = c.fg, bg = float_bg },
    TelescopePromptBorder = { fg = c.fg, bg = float_bg },
    TelescopePromptTitle = { fg = c.fg, bg = float_bg, bold = true },
    TelescopeResultsNormal = { fg = c.fg_dim, bg = float_bg },
    TelescopeResultsBorder = { fg = c.fg, bg = float_bg },
    TelescopeResultsTitle = { fg = c.fg, bg = float_bg, bold = true },
    TelescopePreviewNormal = { fg = c.fg_dim, bg = float_bg },
    TelescopePreviewBorder = { fg = c.fg, bg = float_bg },
    TelescopePreviewTitle = { fg = c.fg, bg = float_bg, bold = true },
    TelescopePromptPrefix = { fg = c.cyan },
    TelescopePromptCounter = { fg = c.gutter },
    TelescopeSelection = { fg = c.fg, bg = c.bg_sel },
    TelescopeSelectionCaret = { fg = c.teal, bg = c.bg_sel },
    TelescopeMultiSelection = { fg = c.orange },
    TelescopeMultiIcon = { fg = c.orange },
    TelescopeMatching = { fg = c.cyan, bold = true },
    TelescopeResultsComment = { fg = c.comment },
    TelescopeResultsDiffAdd = { fg = c.teal },
    TelescopeResultsDiffChange = { fg = c.orange },
    TelescopeResultsDiffDelete = { fg = c.salmon },

    FzfLuaNormal = { fg = c.fg, bg = float_bg },
    FzfLuaBorder = { fg = c.fg, bg = float_bg },
    FzfLuaTitle = { fg = c.fg, bold = true },
    FzfLuaCursorLine = { bg = c.bg_sel },
    FzfLuaFzfMatch = { fg = c.cyan, bold = true },
    FzfLuaHeaderText = { fg = c.orange },
    FzfLuaPathLineNr = { fg = c.comment },

    WhichKey = { fg = c.cyan },
    WhichKeyGroup = { fg = c.teal },
    WhichKeyDesc = { fg = c.fg },
    WhichKeySeparator = { fg = c.gutter },
    WhichKeyFloat = { bg = float_bg },
    WhichKeyBorder = { fg = c.fg, bg = float_bg },
    WhichKeyTitle = { fg = c.fg, bg = float_bg, bold = true },

    NoiceCmdlinePopup = { fg = c.fg, bg = float_bg },
    NoiceCmdlinePopupBorder = { fg = c.fg, bg = float_bg },
    NoiceCmdlineIcon = { fg = c.cyan },
    NoiceConfirmBorder = { fg = c.fg, bg = float_bg },

    NotifyERRORBorder = { fg = c.salmon },
    NotifyWARNBorder = { fg = c.orange },
    NotifyINFOBorder = { fg = c.cyan },
    NotifyDEBUGBorder = { fg = c.comment },
    NotifyTRACEBorder = { fg = c.lilac },
    NotifyERRORIcon = { fg = c.salmon },
    NotifyWARNIcon = { fg = c.orange },
    NotifyINFOIcon = { fg = c.cyan },
    NotifyERRORTitle = { fg = c.salmon },
    NotifyWARNTitle = { fg = c.orange },
    NotifyINFOTitle = { fg = c.cyan },

    SnacksNormal = { fg = c.fg, bg = float_bg },
    SnacksWinBar = { fg = c.comment, bg = float_bg },
    SnacksPickerBorder = { fg = c.fg, bg = float_bg },
    SnacksPickerPrompt = { fg = c.cyan, bg = float_bg },
    SnacksPickerInput = { fg = c.fg, bg = float_bg },
    SnacksPickerList = { fg = c.fg, bg = float_bg },
    SnacksPickerMatch = { fg = c.cyan, bold = true },
    SnacksBackdrop = { bg = "#000000" },
    SnacksDashboardHeader = { fg = c.cyan },
    SnacksDashboardDesc = { fg = c.fg },
    SnacksDashboardKey = { fg = c.orange },
    SnacksDashboardIcon = { fg = c.teal },
    SnacksDashboardFooter = { fg = c.comment },
    SnacksIndent = { fg = c.bg_sel },
    SnacksIndentScope = { fg = c.gutter },

    IblIndent = { fg = c.bg_sel },
    IblScope = { fg = c.gutter },
    MiniIndentscopeSymbol = { fg = c.gutter },

    TroubleNormal = { fg = c.fg, bg = float_bg },
    TroubleText = { fg = c.fg },
    TroubleCount = { fg = c.lilac, bg = c.bg_chrome },

    FlashLabel = { fg = c.bg, bg = c.highlight_yellow, bold = true },
    FlashMatch = { fg = c.fg, bg = c.bg_sel },
    FlashCurrent = { fg = c.bg, bg = c.orange },

    LazyNormal = { fg = c.fg, bg = float_bg },
    LazyButton = { fg = c.fg, bg = c.bg_chrome },
    LazyButtonActive = { fg = c.fg, bg = c.select_blue },
    LazyH1 = { fg = c.fg, bg = c.select_blue, bold = true },
    LazyProgressDone = { fg = c.teal },
    LazyProgressTodo = { fg = c.bg_sel },

    MasonNormal = { fg = c.fg, bg = float_bg },
    MasonHeader = { fg = c.bg, bg = c.cyan, bold = true },
    MasonHighlight = { fg = c.cyan },

    CmpItemAbbr = { fg = c.fg },
    CmpItemAbbrMatch = { fg = c.cyan, bold = true },
    CmpItemKind = { fg = c.lilac },
    CmpItemMenu = { fg = c.comment },
  }
end

local function terminal(c)
  vim.g.terminal_color_0 = c.bg_sel
  vim.g.terminal_color_1 = c.salmon
  vim.g.terminal_color_2 = c.teal
  vim.g.terminal_color_3 = c.sand
  vim.g.terminal_color_4 = c.steel
  vim.g.terminal_color_5 = c.pink
  vim.g.terminal_color_6 = c.purple
  vim.g.terminal_color_7 = c.fg
  vim.g.terminal_color_8 = c.comment
  vim.g.terminal_color_9 = c.salmon
  vim.g.terminal_color_10 = c.mint
  vim.g.terminal_color_11 = c.orange
  vim.g.terminal_color_12 = c.cyan
  vim.g.terminal_color_13 = c.pink
  vim.g.terminal_color_14 = c.lilac
  vim.g.terminal_color_15 = c.fg
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

function M.load()
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
  vim.o.termguicolors = true
  vim.o.background = "dark"
  vim.g.colors_name = "xcode-zenix"

  local c = require("xcode-zenix.palette")
  terminal(c)

  local editor_bg = M.options.transparent and "NONE" or c.bg
  local groups = build(c, M.options)

  for group, spec in pairs(bufferline_groups(c, editor_bg)) do
    groups[group] = spec
  end

  local float_bg = M.options.transparent and "NONE" or c.bg_float
  local menu_bg = M.options.transparent and "NONE" or c.bg_chrome
  for group, spec in pairs(completion_groups(c, float_bg, menu_bg)) do
    groups[group] = spec
  end

  apply_italics(groups, M.options.italic or {})

  for group, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

return M
