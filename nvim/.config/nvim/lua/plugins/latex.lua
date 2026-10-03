-- Builds on the `lang.tex` extra (vimtex + texlab), imported in config/lazy.lua.
-- Keys: <localleader>ll compile (continuous), <localleader>lv view, <localleader>le errors,
-- <localleader>lc clean, <localleader>lt TOC. <localleader> is "\" in LazyVim.
return {
  {
    "lervag/vimtex",
    init = function()
      -- Hyprland/Wayland: plain zathura needs xdotool (X11 only), so use the simple variant
      if vim.fn.executable("zathura") == 1 then
        vim.g.vimtex_view_method = "zathura_simple"
      end
      if vim.fn.executable("latexmk") == 0 and vim.fn.executable("tectonic") == 1 then
        vim.g.vimtex_compiler_method = "tectonic"
      end
      -- Don't pop the quickfix window open for mere warnings (overfull hbox etc.)
      vim.g.vimtex_quickfix_open_on_warning = 0
    end,
  },
}
