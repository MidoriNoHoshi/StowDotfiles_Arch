return {
  {
    "AndrewFerrier/wrapping.nvim",
    config = function()
      require("wrapping").setup {
        softwrap = true, -- Automatically enable soft wrapping
        auto = false, -- Disable auto-wrapping by default
      }
    end,
  },
}
