local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local log = require("neorg").log

-- this file exists
local M = {}

---Show the results of a search engine query in a telescope picker. Meant to be called from rust.
---@param query string
---@param results_json string Stringified json array of file paths to list
M.show_results = function(query, results_json)
    local ok, err = pcall(function()
        local parsed_results = vim.json.decode(results_json)

        pickers
            .new({}, {
                prompt_title = "Query Results (" .. query .. ")",
                finder = finders.new_table({
                    results = parsed_results,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry,
                            ordinal = entry,
                            path = entry,
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

return M
