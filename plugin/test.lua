-- Check if the plugin is already loaded
if vim.g.loaded_test then
	return
end
vim.g.loaded_test = 1

-- Set the plugin path
vim.g["test#plugin_path"] = vim.fn.expand("<sfile>:p:h:h")

-- Set default runners
vim.g["test#default_runners"] = {
	CSharp = { "Xunit", "DotnetTest" },
	Clojure = { "FireplaceTest", "LeinTest" },
	Crystal = { "CrystalSpec" },
	Cpp = { "Catch2" },
	Dart = { "DartTest", "FlutterTest" },
	Elixir = { "ExUnit", "ESpec" },
	Elm = { "ElmTest" },
	Erlang = { "CommonTest", "EUnit", "PropEr" },
	Go = { "GoTest", "Ginkgo", "RichGo", "Delve" },
	Groovy = { "MavenTest", "GradleTest" },
	Haskell = { "StackTest", "CabalTest" },
	Java = { "MavenTest", "GradleTest" },
	JavaScript = {
		"Ava",
		"CucumberJS",
		"DenoTest",
		"Intern",
		"TAP",
		"Teenytest",
		"Karma",
		"Lab",
		"Mocha",
		"NgTest",
		"Nx",
		"Jasmine",
		"Jest",
		"ReactScripts",
		"WebdriverIO",
		"Cypress",
		"VueTestUtils",
		"Playwright",
		"Vitest",
		"Ember",
	},
	Kotlin = { "GradleTest" },
	Lua = { "Busted" },
	Mint = { "MintTest" },
	Nim = { "UnitTest" },
	PHP = { "Codeception", "Dusk", "Pest", "PHPUnit", "Behat", "PHPSpec", "Kahlan", "Peridot" },
	Perl = { "Prove" },
	Python = { "Behave", "DjangoTest", "PyTest", "PyUnit", "Nose", "Nose2", "Mamba" },
	Racket = { "RackUnit" },
	Ruby = { "Rails", "M", "Minitest", "RSpec", "Cucumber", "TestBench" },
	Rust = { "CargoNextest", "CargoTest" },
	Scala = { "SbtTest", "BloopTest" },
	Shell = { "Bats", "ShellSpec" },
	Swift = { "SwiftPM" },
	VimL = { "Themis", "VSpec", "Vader", "Testify", "Vroom" },
	Zig = { "ZigTest" },
	Gleam = { "GleamTest" },
}

-- Set custom strategies, transformations, and runner commands
vim.g["test#custom_strategies"] = vim.tbl_get(vim.g, "test#custom_strategies") or {}
vim.g["test#custom_transformations"] = vim.tbl_get(vim.g, "test#custom_transformations") or {}
vim.g["test#runner_commands"] = vim.tbl_get(vim.g, "test#runner_commands") or {}

-- Define commands
vim.api.nvim_create_user_command("TestNearest", function(opts)
	vim.fn["test#run"]("nearest", vim.split(opts.args, "%s+"))
end, { nargs = "*", bar = true })

vim.api.nvim_create_user_command("TestFile", function(opts)
	vim.fn["test#run"]("file", vim.split(opts.args, "%s+"))
end, { nargs = "*", bar = true, complete = "file" })

vim.api.nvim_create_user_command("TestClass", function(opts)
	vim.fn["test#run"]("class", vim.split(opts.args, "%s+"))
end, { nargs = "*", bar = true })

vim.api.nvim_create_user_command("TestSuite", function(opts)
	vim.fn["test#run"]("suite", vim.split(opts.args, "%s+"))
end, { nargs = "*", bar = true })

vim.api.nvim_create_user_command("TestLast", function(opts)
	vim.fn["test#run_last"](vim.split(opts.args, "%s+"))
end, { nargs = "*", bar = true })

vim.api.nvim_create_user_command("TestVisit", function()
	vim.fn["test#visit"]()
end, { bar = true })

-- Iterate through runners and define additional commands
for language, runners in pairs(vim.fn["test#get_runners"]()) do
	for _, runner in ipairs(runners) do
		if vim.fn.index(vim.g["test#runner_commands"], runner) ~= -1 then
			if vim.fn.exists(":" .. runner) == 2 then
				goto continue
			end
			local runner_id = string.lower(language) .. "#" .. string.lower(runner)
			vim.api.nvim_create_user_command(runner, function(opts)
				vim.fn["test#execute"](runner_id, vim.split(opts.args, "%s+"))
			end, { nargs = "*", bar = true, complete = "file" })
		end
		::continue::
	end
end

-- Set project root if autochdir is enabled
if vim.o.autochdir then
	vim.g["test#project_root"] = vim.fn.getcwd()
end
