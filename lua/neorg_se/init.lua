local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local log = require("neorg").log

local M = {}

---@alias QueryResult [number, string]

---Show the results of a search engine query in a telescope picker. Meant to be called from rust.
---@param query string
---@param results_json string Stringified json array of file paths to list
M.show_results = function(query, results_json)
    local ok, err = pcall(function()
        ---@type QueryResult[]
        local parsed_results = vim.json.decode(results_json)

        pickers
            .new({}, {
                prompt_title = "Query Results (" .. query .. ")",
                finder = finders.new_table({
                    results = parsed_results,
                    ---@param entry QueryResult
                    entry_maker = function(entry)
                        return {
                            value = entry[2],
                            display = ("%.2f: %s"):format(entry[1], entry[2]),
                            ordinal = entry[1],
                            path = entry[2],
                        }
                    end,
                }),
                sorter = conf.file_sorter({}),
                previewer = conf.file_previewer({}),
            })
            :find()
    end)
    if not ok then
        log.error(err)
    end
end

-- track indexed categories. Used as a completion source
M.categories = {}

M.set_categories = function(categories)
    M.categories = categories
end

return M
