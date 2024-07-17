local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "neorg-se"
version = MODREV .. SPECREV

description = {
    summary = "The power of a search engine for your Neorg notes",
    labels = { "neovim" },
    homepage = "https://github.com/benluas/neorg-se",
    license = "MIT",
}

source = {
    url = "http://github.com/benlubas/neorg-se/archive/v" .. MODREV .. ".zip",
}

if MODREV == "scm" then
    source = {
        url = "git://github.com/benlubas/neorg-se",
    }
end

dependencies = {
    "neorg ~> 8",
    "lua >= 5.1",
    "luarocks-build-rust-mlua",
    "telescope.nvim",
}

build = {
    type = "rust-mlua",

    modules = {
        ["libneorg_se"] = "neorg_se",
    },

    install = {
        lua = {
            ["neorg_se.init"] = "lua/neorg_se/init.lua",
            ["neorg.modules.external.search.module"] = "lua/neorg/modules/external/search/module.lua",
        },
    },
}
