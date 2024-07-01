local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "neorg-se"
version = MODREV .. SPECREV

description = {
	summary = "Bringing a search engine to Neorg",
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
}
