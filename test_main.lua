local F = require "flowchat":create("test_main")

F:start("Start")
F:state("hello", "say hello to you")
F:branchN("branch", "stop", "test branch")
F:state("world", "say world to you")
F:switch("select", {
	{
		case = "1",
		target = "target",
	},
	{
		case = "2",
		call = "test_foo",
	}
})
F:call("test_foo", "call test_foo")
F:state("target", "a jmp target")
F:stop("Finish")


