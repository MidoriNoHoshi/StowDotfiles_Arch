-- astro-ls refuses to start unless `typescript.tsdk` points at a TypeScript SDK that
-- still ships tsserverlibrary.js / typescript.js. That breaks:
--   * on fresh clones before `npm install`, or layouts lspconfig can't see into
--   * on TypeScript 7 (the native port), which dropped those files. Mason's
--     astro-language-server package now vendors TS 7, so mason-lspconfig's own
--     fallback is broken too.
-- Prefer the project's TypeScript when usable, otherwise the TS 5.x bundled with vtsls.

local function has_tsdk(dir)
  return dir ~= "" and (vim.uv.fs_stat(dir .. "/tsserverlibrary.js") or vim.uv.fs_stat(dir .. "/typescript.js")) ~= nil
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        astro = {
          before_init = function(_, config)
            local tsdk = require("lspconfig.util").get_typescript_server_path(config.root_dir)
            if not has_tsdk(tsdk) then
              tsdk = LazyVim.get_pkg_path("vtsls", "/node_modules/@vtsls/language-server/node_modules/typescript/lib")
            end
            -- mutate in place: the initialize params already reference this table
            config.init_options.typescript = config.init_options.typescript or {}
            config.init_options.typescript.tsdk = tsdk
          end,
        },
      },
      setup = {
        -- Enable astro ourselves: this keeps mason-lspconfig from auto-enabling it,
        -- which would replace the before_init above with its broken TS lookup.
        astro = function(server, opts)
          vim.lsp.config(server, opts)
          vim.lsp.enable(server)
          return true
        end,
      },
    },
  },
  -- Opting out of mason-lspconfig also drops astro from its auto-install list
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "astro-language-server" } },
  },
}
