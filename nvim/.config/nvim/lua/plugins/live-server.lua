return {
  "barrett-ruth/live-server.nvim",
  build = "npm install -g live-server", -- Ensures it stays updated
  cmd = { "LiveServerStart", "LiveServerStop" },
  config = function()
    require("live-server").setup {
      args = { "--browser=zen-browser" }, -- Change to "google-chrome-stable" or "brave" if needed
    }
  end,
  -- Keybinding to start/stop quickly
  keys = {
    { "<leader>Sl", "<cmd>LiveServerStart<cr>", desc = "Start Live Server" },
    { "<leader>Sq", "<cmd>LiveServerStop<cr>", desc = "Stop Live Server" },
  },
}
