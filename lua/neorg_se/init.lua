local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local log = require("neorg").log
local finders = require("telescope.finders")
local sers = require("libneorg_se")
local sorters = require("telescope.sorters")

local M = {}

---Show the results of a search engine query in a telescope picker. Meant to be called from rust.
---@param type "fulltext" | "categories" the type of query that's being run
M.open_telescope_picker = function(type)
    local ok, err = pcall(function()
        pickers
            .new({}, {
                prompt_title = "Query Results (" .. type .. ")",
                finder = finders.new_dynamic({
                    fn = function(query)
                        return sers.query(type, query)
                    end,
                    entry_maker = function(entry)
                        return {
                            value = entry.path,
                            display = ("%.2f: %s"):format(entry.score, entry.path),
                            ordinal = entry.score,
                            path = entry.path,
                        }
                    end,
                }),
                sorter = sorters.highlighter_only({}),
                previewer = conf.file_previewer({}),
            })
            :find()
    end)
    if not ok then
        log.error(err)
    end
end

return M
