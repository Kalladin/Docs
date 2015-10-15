aa = 3

print(aa)
local m = require 'test'

m.func1();
m.func3();
print(m.version);


                local data_module = require "data";
                if data_module.get_age("dog") <= 3 then
                        print("my dog age :", data_module.get_age("dog"))
                        local ret, err = data_module.set_age("11dog", data_module.get_age("dog")+1)
			--print(ret,err)
			if not ret then
				print(err)
			else
                        	print("after a year, my dog age :", data_module.get_age("dog"))
                	end
		else
                        print("my dog is too old:",data_module.get_age("dog"))
                end

