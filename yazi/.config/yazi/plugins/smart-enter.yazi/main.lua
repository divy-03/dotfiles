--- @sync entry

--- yazi binds `l` to `enter`, which only descends into directories and does
--- nothing at all on a file, so vim-style "move right to go in" dead-ends on
--- every image. This makes `l` mean "go in" for whatever is hovered: descend if
--- it is a directory, otherwise hand it to the [open] rules in yazi.toml.
---
--- `hovered = true` on purpose -- `l` is a navigation key, so it acts on the one
--- file under the cursor. <Enter> remains the key that opens a whole selection.
return {
	entry = function()
		local h = cx.active.current.hovered
		ya.emit(h and h.cha.is_dir and "enter" or "open", { hovered = true })
	end,
}
