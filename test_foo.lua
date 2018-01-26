local F = require "flowchat":create("test_foo")

F:start("Start")
F:state("hello", "say hello to you")
F:state("world", "say world to you")
F:stop("Stop")

