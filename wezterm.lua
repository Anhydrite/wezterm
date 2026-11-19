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
-- IMPORTANT (barre verticale gauche) : doit rester FALSE. Le calcul de taille
-- des panes (resize.rs) ne soustrait la largeur de la barre que si ce flag est
-- false ; sinon les panes sont dimensionnes trop larges (debordement).
config.hide_tab_bar_if_only_one_tab = false
config.enable_tab_bar = true
config.window_frame = {
  active_titlebar_bg = "#0a1628",
  inactive_titlebar_bg = "#060f1d",
}

-- === Étape A : onglets verticaux à gauche (fork PR #7574) ===
config.tab_bar_position = 'Left'
config.tab_bar_width = '250px' -- largeur (cellules) selon fork

-- === Étape B : domaines ssh ottawa ===
-- ottawa     : SSH direct (Ctrl+Shift+O) -> onglet dans la fenetre courante,
--              aucune fenetre mux parasite.
-- ottawa-mux : mux persistant (Ctrl+Shift+A via wezterm connect) -> restaure
--              la session (quad-panes / taches en cours) dans une fenetre dediee.
config.ssh_domains = {
  {
    name = 'ottawa',
    remote_address = 'ottawa',
    username = 'root',
    multiplexing = 'None',
  },
  {
    name = 'ottawa-mux',
    remote_address = 'ottawa',
    username = 'root',
    multiplexing = 'WezTerm',
  },
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

local function current_cwd(pane)
  local dir = pane:get_current_working_dir()
  return dir and dir.file_path or nil
end

local function smart_split(window, pane)
  local dims = pane:get_dimensions()
  local spawn = {
    domain = "CurrentPaneDomain",
    cwd = current_cwd(pane),
  }
  if dims.pixel_width > dims.pixel_height then
    window:perform_action(wezterm.action.SplitHorizontal(spawn), pane)
  else
    window:perform_action(wezterm.action.SplitVertical(spawn), pane)
  end
end

local function spawn_with_layout(window, pane)
  window:perform_action(
    wezterm.action.SpawnCommandInNewTab {
      domain = "CurrentPaneDomain",
      cwd = current_cwd(pane),
    },
    pane
  )
end

-- Attache la session mux persistante ottawa DANS la fenetre courante
-- (AttachDomain importe les tabs du mux distant dans la fenetre active,
--  contrairement a `wezterm connect` qui ouvre une fenetre dediee).
local function attach_ottawa(window, pane)
  window:perform_action(wezterm.action.AttachDomain("ottawa-mux"), pane)
end

-- Ctrl+Shift+O : propose un hostname/domaine. A la selection :
--  - domaine mux detache -> AttachDomain (restaure les panes distants
--    existants DANS la fenetre courante, sans nouvelle fenetre)
--  - sinon -> SpawnTab dans ce domaine.
local function open_remote(window, pane)
  local choices = {}
  for _, dom in ipairs(wezterm.mux.all_domains()) do
    local name = dom:name()
    if name ~= "local" and dom:is_spawnable() then
      local st = dom:state()
      local suffix = (st == "Detached") and "  (session distante)" or ""
      table.insert(choices, {
        label = name .. suffix,
        id = name,
      })
    end
  end

  if #choices == 0 then
    window:toast_notification("Connexion distante", "Aucun domaine distant disponible", nil, 3000)
    return
  end

  window:perform_action(
    wezterm.action.InputSelector {
      title = "Connexion distante",
      description = "Choisir un host / domaine, Entree pour se connecter",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(win, p, id, _label)
        if not id or id == "" then
          return
        end
        local dom = wezterm.mux.get_domain(id)
        if dom and dom:state() == "Detached" then
          win:perform_action(wezterm.action.AttachDomain(id), p)
        else
          win:perform_action(wezterm.action.SpawnTab { DomainName = id }, p)
        end
      end),
    },
    pane
  )
end

-- Menu dépliant : tous les panes groupés par domaine (local / ottawa / ...)
local function pane_menu(window, pane)
  local mux = wezterm.mux

  local by_domain = {}
  local domain_order = {}
  for _, win in ipairs(mux.all_windows()) do
    local win_id = win:window_id()
    for _, tab in ipairs(win:tabs()) do
      local tab_id = tab:tab_id()
      for _, mpane in ipairs(tab:panes()) do
        local d = mpane:get_domain_name()
        if not d or d == "" then
          d = "local"
        end
        if not by_domain[d] then
          by_domain[d] = {}
          table.insert(domain_order, d)
        end
        table.insert(by_domain[d], {
          pane_id = mpane:pane_id(),
          title = mpane:get_title(),
          window_id = win_id,
          tab_id = tab_id,
        })
      end
    end
  end

  table.sort(domain_order, function(a, b)
    if a == "local" then
      return true
    elseif b == "local" then
      return false
    end
    return a < b
  end)

  local choices = {}
  for _, d in ipairs(domain_order) do
    table.insert(choices, { label = "▾ " .. string.upper(d), id = "" })
    for _, e in ipairs(by_domain[d]) do
      table.insert(choices, {
        label = string.format("   └ %s  (w%d t%d)", e.title or "?", e.window_id, e.tab_id),
        id = tostring(e.pane_id),
      })
    end
  end

  window:perform_action(
    wezterm.action.InputSelector {
      title = "Panes par groupe",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(_win, _pane, id, _label)
        if id and id ~= "" then
          local pid = tonumber(id)
          local target = pid and wezterm.mux.get_pane(pid)
          if target then
            target:activate()
          end
        end
      end),
    },
    pane
  )
end

-- === Regroupement automatique par domaine ===
-- A chaque apparition d'un nouvel onglet, on le deplace une seule fois dans
-- son groupe de domaine (pas de boucle => pas de clignotement).
local known_tabs = {}

local function tab_domain(tab)
  local p = tab:active_pane()
  return (p and p:get_domain_name()) or "local"
end

wezterm.on("update-status", function(window, pane)
  local wid = window:window_id()
  local tabs = window:mux_window():tabs()

  local cur = {}
  for _, t in ipairs(tabs) do
    cur[t:tab_id()] = true
  end

  local prev = known_tabs[wid]
  if not prev then
    known_tabs[wid] = cur
    return
  end

  -- Identifie les onglets nouvellement apparus
  local new_ids = {}
  for _, t in ipairs(tabs) do
    local id = t:tab_id()
    if not prev[id] then
      new_ids[#new_ids + 1] = id
    end
  end
  known_tabs[wid] = cur

  if #new_ids == 0 then
    return
  end

  local active = window:active_tab()
  local active_id = active and active:tab_id() or nil

  for _, id in ipairs(new_ids) do
    -- Le nouvel onglet est generalement l'actif (juste cree) -> MoveTab suffit.
    if id == active_id then
      local tabs2 = window:mux_window():tabs()
      local newpos, dom
      for i, t in ipairs(tabs2) do
        if t:tab_id() == id then
          newpos = i
          dom = tab_domain(t)
        end
      end
      if newpos then
        local last_same = nil
        for i = 1, newpos - 1 do
          if tab_domain(tabs2[i]) == dom then
            last_same = i
          end
        end
        -- Deplace seulement s'il existe un groupe du meme domaine avant,
        -- et que l'onglet n'est pas deja colle juste apres.
        if last_same and last_same < newpos - 1 then
          window:perform_action(wezterm.action.MoveTab(last_same), pane)
        end
      end
    end
  end
end)

config.status_update_interval = 500

config.keys = {
  { key = "E", mods = "CTRL|SHIFT", action = wezterm.action.TogglePaneZoomState },
  { key = "t", mods = "CTRL", action = wezterm.action_callback(smart_split) },
  { key = "w", mods = "CTRL", action = wezterm.action.CloseCurrentPane { confirm = false } },
  { key = "T", mods = "CTRL|SHIFT", action = wezterm.action_callback(spawn_with_layout) },
  { key = "W", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab { confirm = false } },
  { key = "B", mods = "CTRL|SHIFT", action = wezterm.action_callback(broadcast_to_all) },
  { key = "O", mods = "CTRL|SHIFT", action = wezterm.action_callback(open_remote) },
  { key = "A", mods = "CTRL|SHIFT", action = wezterm.action_callback(attach_ottawa) },
  { key = "D", mods = "CTRL|SHIFT", action = wezterm.action.DetachDomain { DomainName = "ottawa-mux" } },
  { key = "G", mods = "CTRL|SHIFT", action = wezterm.action_callback(pane_menu) },
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
-- Nom de groupe = hostname de la machine (oslo pour local, ottawa pour distant)
local LOCAL_HOST = wezterm.hostname()
local DOMAIN_STYLE = {
  ["local"] = { label = LOCAL_HOST, bg = "#0a1628", fg = "#c4b5fd" },
  ottawa = { label = "ottawa", bg = "#2b2042", fg = "#a29bfe" },
  ["ottawa-mux"] = { label = "ottawa", bg = "#2b2042", fg = "#a29bfe" },
}

local function domain_of(tab)
  local pane = tab.active_pane
  return (pane and pane.domain_name) or "local"
end

-- Separateur U+E000 (PUA) : la barre verticale patchee le transforme en
-- ligne d'en-tete de groupe distincte au-dessus de l'onglet.
local GROUP_SEP = "\238\128\128"

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
  local domain = domain_of(tab)

  -- tab.tab_index est 0-based ; `tabs` est 1-based.
  -- Onglet précédent = tabs[tab.tab_index] (1-based) quand tab_index > 0.
  local prev = nil
  if tab.tab_index and tab.tab_index > 0 then
    local prev_tab = tabs[tab.tab_index]
    if prev_tab then
      prev = domain_of(prev_tab)
    end
  end
  -- En-tete de dossier uniquement a la PREMIERE occurrence d'un domaine.
  -- (evite un doublon « LOCAL » quand on revient a local apres ottawa)
  local seen = {}
  if tab.tab_index then
    for i = 1, tab.tab_index do
      local t = tabs[i]
      if t then
        seen[domain_of(t)] = true
      end
    end
  end
  local is_folder = not seen[domain]

  local style = DOMAIN_STYLE[domain]
    or { label = (domain:gsub("%-mux$", "")), bg = "#1e3a5f", fg = "#dfe6e9" }

  local title = tab.active_pane and tab.active_pane.title or "wezterm"

  if is_folder then
    -- En-tete de groupe sur sa propre ligne (via GROUP_SEP) puis titre en dessous.
    return {
      { Background = { Color = style.bg } },
      { Foreground = { Color = style.fg } },
      { Attribute = { Intensity = "Bold" } },
      { Text = "▾ " .. style.label },
      { Attribute = { Intensity = "Normal" } },
      { Text = GROUP_SEP .. title },
    }
  else
    -- Ligne "enfant" indentee ; rappel du domaine s'il reapparait apres un autre groupe
    local rejoined = (prev ~= nil) and (prev ~= domain)
    local prefix = "   └ "
    if rejoined then
      prefix = "   ↳ [" .. style.label .. "] "
    end
    return {
      { Background = { Color = style.bg } },
      { Foreground = { Color = style.fg } },
      { Text = prefix .. title },
    }
  end
end)

return config
