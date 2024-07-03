# neorg-se

> [!WARNING]
> This is a Work in Progress. Some things are working, but I'm still experimenting with this idea.
> Everything is subject to change.

Search text file content via the [Tantivy](https://github.com/quickwit-oss/tantivy) search engine,
all within Neovim.

---

## Commands

- `Neorg search index` - Create the search engine index for the current workspace. Must be run each
time you launch nvim before you can run a query (WIP like I said)
- `Neorg search query` - Provide a prompt used to search document titles and text


## Install

Uhhhh... Maybe clone this one and build it yourself for now...

```lua
["external.search"] = {
    config = {
        -- will autodetect if you load the plugin correctly, and build the exe with cargo build and don't move it.
        bin_path = "path/to/bin",
    },
},
```
