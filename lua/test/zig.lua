vim.g["test#zig#patterns"] = {
	whole_match = 1,
	test = { '\\v^\\s*test\\s(")\\zs%(.{-}%(\\\\1)?){-}\\ze1' },
	namespace = {},
}
