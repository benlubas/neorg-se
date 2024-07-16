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
    "lua == 5.1",
    "luarocks-build-rust-mlua",
}

build = {
    type = "rust-mlua",

    modules = {
        -- Native library expected in `<target_path>/release/libmy_module.so` (linux; uses right name on macos/windows)
        "neorg_se",
    },

    install = {
        lua = {
            ["lua/neorg_se"] = "./lua/neorg_se/init.lua",
            ["lua/neorg/modules/external/search"] = "./lua/neorg/modules/external/search/module.lua",
        }
    }
}
