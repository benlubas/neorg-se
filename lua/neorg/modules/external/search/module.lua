--[[
    file: Search-Module
    title: The Power Of a Search Engine in Neorg
    summary: Search for files in your workspace using the Tantivy search engine.
    internal: false
    ---

This plugin is a little insane I think. A lot of this is based on the way sniprun does things.
Please refer to it over this plugin as reference material.

--]]

local neorg = require("neorg.core")
local modules = neorg.modules
local log = neorg.log

local module = modules.create("external.search")

local DEBUG = true

module.config.public = {
    bin_path = vim.fn.fnamemodify(vim.api.nvim_get_runtime_file("lua/neorg_se.lua", false)[1], ":p:h:h")
        .. "/target/"
        .. (DEBUG and "debug" or "release")
        .. "/neorg-se",

    index_on_launch = true,
}

print("module.config.public.bin_path:", module.config.public.bin_path)

module.setup = function()
    return {
        success = true,
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
                            min_args = 0,
                        },
                        categories = {
                            name = "search.query.categories",
                            min_args = 0,
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
end

---@class SearchResult
---@field file_path string absolute file path
---@field confidence number how close of a match this is (ideally they're already in sorted order though)

---@alias DocumentField "heading" | "metadata" | "categories" | "authors" | "title" | "body"

module.private.job_id = nil

---Start the rust process as a background job
module.private.start = function()
    if module.private.job_id ~= nil then
        return
    end
    module.private.job_id = vim.fn.jobstart({ module.config.public.bin_path }, {
        rpc = true,
    })
end

module.private.notify_rpc = function(method, ...)
    module.private.start()
    local status, _ = pcall(vim.rpcnotify, module.private.job_id, method, ...)
    if not status then
        print("we crashed")
        module.private.terminate()
        module.private.start()
        vim.rpcnotify(module.private.job_id, method, ...)
    end
end

module.private.terminate = function()
    vim.fn.jobstop(module.private.job_id)
    module.private.job_id = nil
end

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

module.private["search.query.fulltext"] = function(event)
    local query = event.content
    if not vim.tbl_isempty(query) then
        -- call a function with the query
        module.private.notify_rpc("query_fulltext", vim.iter(query):join(" "))
    else
        -- prompt for a query, ideally with telescope and live updates? I'm not sure how that will
        -- work... :/
        vim.schedule(function()
            vim.ui.input({ prompt = "Search Query:" }, function(text)
                module.private.notify_rpc("query_fulltext", text)
            end)
        end)
    end
end

module.private["search.query.categories"] = function(event)
    local query = event.content
    if not vim.tbl_isempty(query) then
        module.private.notify_rpc("query_categories", vim.iter(query):join(" "))
    else
        vim.schedule(function()
            vim.ui.input({ prompt = "Search Categories:" }, function(text)
                module.private.notify_rpc("query_categories", text)
            end)
        end)
    end
end

module.private["search.index"] = function(_event)
    local ws = dirman.get_current_workspace()
    -- P(ws[1], tostring(ws[2]))
    module.private.notify_rpc("index", ws[1], tostring(ws[2]))
end

return module
