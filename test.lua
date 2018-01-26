local flow = require "flowchat"
local output = flow:flow("test_main")
print(table.concat(output, "\n"))


