--[[
    file: Search-Module
    title: The Power Of a Search Engine in Neorg
    summary: Search for files in your workspace using the Tantivy search engine.
    internal: false
    ---

Searching things

--]]

local neorg = require("neorg.core")
local modules = neorg.modules
local log = neorg.log

local module = modules.create("external.search")

local sers

module.config.public = {
    index_on_launch = true,
}

module.setup = function()
    local ok, res = pcall(require, "libneorg_se")
    if ok then
        sers = res
    else
        log.error("[Neorg Search] Failed to load `libneorg_se`.\n"..res)
    end
    return {
        success = ok,
        requires = {
            "core.dirman",
            "core.neorgcmd",
            "core.ui.text_popup",
        },
    }
end

local dirman
module.load = function()
    log.info("loaded search module")
    module.required["core.neorgcmd"].add_commands_from_table({
        search = {
            min_args = 0,
            max_args = 1,
            name = "search",
            subcommands = {
                query = {
                    min_args = 1,
                    name = "search.query",
                    subcommands = {
                        fulltext = {
                            name = "search.query.fulltext",
                            args = 0,
                        },
                        categories = {
                            name = "search.query.categories",
                            args = 0,
                        },
                    },
                },
                index = {
                    args = 0,
                    name = "search.index",
                },
            },
        },
    })

    dirman = module.required["core.dirman"] ---@type core.dirman

    if module.config.public.index_on_launch then
        module.private["search.index"]()
    end

    --- Setup keybinds
    vim.keymap.set("n", "<Plug>(neorg.search.categories)", module.private["search.query.categories"], { desc = "Search Neorg Categories" })
    vim.keymap.set("n", "<Plug>(neorg.search.fulltext)", module.private["search.query.fulltext"], { desc = "Search Neorg Categories" })
    vim.keymap.set("n", "<Plug>(neorg.search.update_index)", module.private["search.index"], { desc = "Search Neorg Categories" })
end

---@class external.search
module.public = {
    get_categories = function()
        -- return require("neorg_se").categories
        return sers.list_categories()
    end,
}

---@class SearchResult
---@field file_path string absolute file path
---@field confidence number how close of a match this is (ideally they're already in sorted order though)

---@alias DocumentField "heading" | "metadata" | "categories" | "authors" | "title" | "body"

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["search.query.fulltext"] = true,
        ["search.query.categories"] = true,
        ["search.index"] = true,
    },
}

module.on_event = function(event)
    if module.private[event.split_type[2]] then
        module.private[event.split_type[2]](event)
    end
end

module.private["search.query.fulltext"] = function(_)
    require("neorg_se").open_telescope_picker("fulltext")
end

module.private["search.query.categories"] = function(_)
    require("neorg_se").open_telescope_picker("categories")
end

module.private["search.index"] = function(_)
    local ws = dirman.get_current_workspace()

    -- note that this function spawns a thread to do the work and then returns immediately so it
    -- doesn't block or contribute to startup time
    sers.index(ws[1], tostring(ws[2]))
end

return module
