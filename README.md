# neorg-se

> [!WARNING]
> This is a Work in Progress. Nothing is working right now, I'm still experimenting with this idea.

Search text file content via the [Tantivy](https://github.com/quickwit-oss/tantivy) search engine,
all within Neovim.

---

## Commands

- `Neorg search fulltext` - Provide a prompt used to search document text (including headings)
- `Neorg search headings` - Provide a prompt used to search for headings

## Install

Install this plugin and load it by adding this to your neorg config:

```lua
["external.search"] = {},
```

I'm not sure what the config will look like at this moment. Maybe a custom data directory? I'm just
planning to use the neorg data directory wherever that may be.
