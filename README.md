# neorg-se

> [!WARNING]
> This is a Work in Progress. Some things are working, but I'm still experimenting with this idea.
> Everything is subject to change. Performance is meh at best.

Search text file content via the [Tantivy](https://github.com/quickwit-oss/tantivy) search engine,
all within Neovim.

---

## Commands

-   `Neorg search index` - Create the search engine index for the current workspace. Must be run each
    time you launch nvim before you can run a query (WIP like I said)
-   `Neorg search query fulltext` - "normal" search. Searches body text, title, and categories
-   `Neorg search query categories` - search for all files tagged with one or more categories

## Install

Install like normal, **you need to be using a package manger that supports luarocks!**

```lua
["external.search"] = {
    -- values shown are the default
    config = {
        -- Index the workspace when neovim launches. This process happens on a separate thread, so
        -- it doesn't significantly contribute to startup time or block neovim
        index_on_start = true,
    }
},
```

## Integrations

This plugin can also act as a category completion source for
[benlubas/neorg-interim-ls](https://github.com/benlubas/neorg-interim-ls). No additional
configuration is required here. Just install and load this module and configure the rest in
neorg-interim-ls!
