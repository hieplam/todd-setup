local markdownlint_config = vim.fs.joinpath(vim.fn.stdpath("config"), ".markdownlint.jsonc")

return {
  -- disable MD013 (line-length) and MD060 (table-column-style) everywhere,
  -- regardless of which project's markdown file is open
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", markdownlint_config },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", markdownlint_config },
        },
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {},
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
    },
  },
  {
    -- nvim-lint pipes the buffer through stdin, so markdownlint-cli2 resolves its
    -- config against nvim's cwd rather than the file's directory. Point it at a
    -- fixed global config so the same rules apply to every markdown file.
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function()
      require("lint").linters["markdownlint-cli2"].args =
        { "--config", vim.fn.expand("~/.markdownlint-cli2.yaml"), "-" }
    end,
  },
}
