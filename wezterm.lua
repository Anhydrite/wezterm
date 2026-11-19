local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ponytail: WSL domain removed — useless on Linux

wezterm.on("gui-startup", function(cmd)
  local mux = wezterm.mux
  local tab, pane, window = mux.spawn_window(cmd or {})

  local right_top = pane:split({ direction = "Right" })
  right_top:split({ direction = "Bottom" })
end)

config.initial_cols = 120
config.initial_rows = 28
config.window_decorations = "NONE"

-- === Winter Ice Theme ===
config.color_schemes = {
  ["Winter Ice"] = {
    -- Deep frozen night background
    background = "#0a1628",
    -- Ice mist text
    foreground = "#c4b5fd",

    -- Cursor
    cursor_bg = "#74b9ff",
    cursor_fg = "#0a1628",
    cursor_border = "#74b9ff",

    -- Selection
    selection_fg = "#ffffff",
    selection_bg = "#1e3a5f",

    -- Scrollbar and split
    scrollbar_thumb = "#1e3a5f",
    split = "#2d4a7a",

    -- ANSI colors (icy palette)
    ansi = {
      "#0a1628",  -- black (deep ice)
      "#ff6b6b",  -- red (ember in snow)
      "#7bed9f",  -- green (aurora)
      "#ffd93d",  -- yellow (northern light)
      "#74b9ff",  -- blue (glacier)
      "#a29bfe",  -- magenta (violet frost)
      "#00cec9",  -- cyan (ice crystal)
      "#dfe6e9",  -- white (snow)
    },

    -- Bright colors
    brights = {
      "#a8a8c0",  -- dim charcoal → silver ice (lisible)
      "#ff7675",  -- bright ember
      "#55efc4",  -- bright aurora
      "#ffeaa7",  -- bright light
      "#0984e3",  -- bright glacier
      "#6c5ce7",  -- bright violet
      "#00b894",  -- bright crystal
      "#ffffff",  -- pure snow
    },
  },
}

config.color_scheme = "Winter Ice"

-- === Background: image sur Windows, gradient natif sur Linux ===
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
  config.window_background_image = "C:/Users/robin/Downloads/gradient.png"
  config.window_background_image_hsb = {
    brightness = 0.5,
    hue = 1.0,
    saturation = 1.0,
  }
else
  config.window_background_gradient = {
    orientation = "Vertical",
    colors = { "#141020", "#1e1830", "#2e2440", "#3e3050", "#4a3858", "#3a2e48" },
    interpolation = "Linear",
    blend = "Rgb",
  }
end
config.window_background_opacity = 0.95

config.window_padding = {
  left = 10,
  right = 10,
  top = 10,
  bottom = 10,
}

-- Épaisseur du séparateur entre panes (utilise underline_thickness en interne)
config.underline_thickness = "3px"

-- Tab bar
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_frame = {
  active_titlebar_bg = "#0a1628",
  inactive_titlebar_bg = "#060f1d",
}

-- === Étape A : onglets verticaux à gauche (fork PR #7574) ===
config.tab_bar_position = 'Left'
config.tab_bar_width = '250px' -- largeur (cellules) selon fork

-- === Étape B : domaine ssh ottawa ===
config.ssh_domains = {
  { name = 'ottawa', remote_address = 'ottawa', username = 'root' },
}

-- Font
config.font = wezterm.font_with_fallback({
  { family = "JetBrains Mono", weight = "Medium" },
  "Symbols Nerd Font Mono",
})
config.font_size = 11.0

-- Cursor
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500

-- Links: Ctrl+Click pour ouvrir (pas le clic simple)
-- mouse_reporting = true : sans ça, WezTerm ignore la liaison quand une app
-- (maki, vim, tmux...) capture la souris, et Ctrl+Click ne fait rien.
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    mouse_reporting = true,
    action = "OpenLinkAtMouseCursor",
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = "OpenLinkAtMouseCursor",
  },
  -- Desactive le 2026-11-05 : ce binding avalait le relachement du clic
  -- gauche simple, donc maki ne recevait jamais le Up et aucun clic n'etait
  -- dispatche. A retablir avec mouse_reporting = true si besoin.
  -- {
  --   event = { Up = { streak = 1, button = "Left" } },
  --   mods = "NONE",
  --   action = wezterm.action.Nop,
  -- },
}

-- === Broadcast: envoyer une commande à tous les panes de l'onglet ===
local function broadcast_to_all(window, pane)
  local all_panes = pane:tab():panes()

  window:perform_action(
    wezterm.action.PromptInputLine {
      description = "⌨ Broadcast:",
      action = wezterm.action_callback(function(_, _, text)
        if text and #text > 0 then
          for _, p in ipairs(all_panes) do
            p:send_text(text .. "\n")
          end
        end
      end),
    },
    pane
  )
end

local function smart_split(window, pane)
  local dims = pane:get_dimensions()
  if dims.pixel_width > dims.pixel_height then
    window:perform_action(wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" }, pane)
  else
    window:perform_action(wezterm.action.SplitVertical { domain = "CurrentPaneDomain" }, pane)
  end
end

local function spawn_with_layout(window, pane)
  window:perform_action(wezterm.action.SpawnTab "CurrentPaneDomain", pane)
end

config.keys = {
  { key = "E", mods = "CTRL|SHIFT", action = wezterm.action.TogglePaneZoomState },
  { key = "t", mods = "CTRL", action = wezterm.action_callback(smart_split) },
  { key = "w", mods = "CTRL", action = wezterm.action.CloseCurrentPane { confirm = false } },
  { key = "T", mods = "CTRL|SHIFT", action = wezterm.action_callback(spawn_with_layout) },
  { key = "W", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab { confirm = false } },
  { key = "B", mods = "CTRL|SHIFT", action = wezterm.action_callback(broadcast_to_all) },
  { key = "&", mods = "ALT", action = wezterm.action.ActivateTab(0) },
  { key = "2", mods = "ALT", action = wezterm.action.ActivateTab(1) },
  { key = '"', mods = "ALT", action = wezterm.action.ActivateTab(2) },
  { key = "'", mods = "ALT", action = wezterm.action.ActivateTab(3) },
  { key = "(", mods = "ALT", action = wezterm.action.ActivateTab(4) },
  { key = "-", mods = "ALT", action = wezterm.action.ActivateTab(5) },
  { key = "è", mods = "ALT", action = wezterm.action.ActivateTab(6) },
  { key = "_", mods = "ALT", action = wezterm.action.ActivateTab(7) },
  { key = "ç", mods = "ALT", action = wezterm.action.ActivateTab(8) },
  { key = "à", mods = "ALT", action = wezterm.action.ActivateTab(9) },
}

-- === Étape C : groupement visuel local vs distant ===
local DOMAIN_STYLE = {
  ["local"] = { label = "LOCAL", bg = "#0a1628", fg = "#c4b5fd" },
  ottawa = { label = "OTTAWA", bg = "#2b2042", fg = "#a29bfe" },
}

local function domain_of(tab)
  local pane = tab.active_pane
  return (pane and pane.domain_name) or "local"
end

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
  local domain = domain_of(tab)

  -- Index de l'onglet courant dans `tabs` (ordre gauche->droite)
  local idx = 0
  for i, t in ipairs(tabs) do
    if t == tab then idx = i end
  end

  -- En-tête de groupe uniquement sur le premier onglet de chaque domaine
  local prev = (idx and idx > 1) and domain_of(tabs[idx - 1]) or nil
  local new_group = prev and prev ~= domain

  local style = DOMAIN_STYLE[domain] or { label = domain:upper(), bg = "#1e3a5f", fg = "#dfe6e9" }
  local header = new_group and (" " .. style.label .. " ") or " "

  return {
    { Background = { Color = style.bg } },
    { Foreground = { Color = style.fg } },
    -- En-tête de groupe + titre du pane
    { Attribute = { Intensity = "Bold" } },
    { Text = header },
    { Attribute = { Intensity = "Normal" } },
    { Text = tab.active_pane and tab.active_pane.title or "wezterm" },
  }
end)

return config
