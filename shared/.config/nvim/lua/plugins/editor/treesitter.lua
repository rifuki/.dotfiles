-- Pinned to `master` on purpose. Upstream made `main` the default branch, and
-- because this spec named no branch, lazy.nvim silently followed it. `main` is a
-- full rewrite that requires Neovim 0.12 nightly; this machine runs 0.11.6, so
-- every call into it died on `vim.list.unique` (a 0.12 stdlib function). The
-- options below -- ensure_installed / auto_install / highlight / indent -- are the
-- `master` API and were being ignored wholesale, which left treesitter inert: no
-- parser attached, no treesitter highlighting, and no folds.
-- Upstream keeps `master` available precisely for Neovim 0.11.
return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    dependencies = {
        "windwp/nvim-ts-autotag",
    },
    opts = {
        ensure_installed = {
            "vim",
            "lua",
            "vimdoc",
            "bash",
            "json",
            "gitignore",
            "toml",
            "yaml",
            "nginx",
            "sql",
            "html",
            "css",
            "javascript",
            "typescript",
            "tsx",
            "rust",
            "markdown",
            "markdown_inline",
            "caddy",
            "solidity",
        },
        auto_install = true,
        highlight = {
            enable = true,
        },
        indent = {
            enable = true,
        },
    },
}
