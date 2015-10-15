module = {}
 
module.version = "0.1"
 
function module.func1()
    return "this is a public function!\n"
end
 
local function func2()
    return "this is a private function!"
end
 
function module.func3()
    return func2()
end
 
return module