# ngx.shared.DICT API 

Use nginx shm-based mechanism to share data on server-wide scope (worker process can share data on the same server).

https://www.nginx.com/resources/wiki/modules/lua/#ngx-shared-dict
## Scope 
cross worker processes

- LRU
- complex lua value need to serialize to put in
- cache operations (get/set) will block 
- less memory used (shared by all worker processes)
- survive HUP signal

## Test Process

1. add get/set location blocks to nginx.conf
<pre><code>
http {
    lua_shared_dict contacts 10m;
    server {
        location /set {
            content_by_lua '
                local contacts = ngx.shared.contacts
                ngx.say("### Worker Process:", ngx.worker.pid(), " ###")
                contacts:set("Jim", "0932123456")
                ngx.say("STORED")
            ';
        }
        location /get {
            content_by_lua '
                local contacts = ngx.shared.contacts
                ngx.say("### Worker Process:", ngx.worker.pid(), " ###")
                os.execute("sleep 3")
                ngx.say("Jim:", contacts:get("Jim"))
            ';
        }
        location /delete {
            content_by_lua '
                local contacts = ngx.shared.contacts
                ngx.say("### Worker Process:", ngx.worker.pid(), " ###")
                contacts:delete("Jim");
                ngx.say("Delete contacts Jim");
            ';
        }
    }
}
</code></pre>

2. Tests  
[Scope]Get/Set/Delete in different worker process
<pre><code> 
$ curl http://127.0.0.1/set
### Worker Process:11588 ###
STORED
$ curl http://127.0.0.1/get
### Worker Process:11588 ###
Jim:0932123456
$ curl http://127.0.0.1/get
### Worker Process:11592 ###
Jim:0932123456
$ curl http://127.0.0.1/get
### Worker Process:11586 ###
Jim:0932123456
$ curl http://127.0.0.1/delete
### Worker Process:11591 ###
Delete contacts Jim
$ curl http://127.0.0.1/get
### Worker Process:11591 ###
Jim:nil
</code></pre>  
[HUP Survived] Set then reload the nginx server
<pre><code>
$ curl http://127.0.0.1/set
### Worker Process:11588 ###
STORED
$ nginx -s reload
$ curl http://127.0.0.1/get
### Worker Process:11588 ###
Jim:0932123456
</code></pre>


## Issue
shared.DICT is not an array, so it can't gurantee that key will follow FIFO principle.
If we produce keys and use keys simutaneously, you may not get some keys forever. (Key producing speed > consuming speed)

http://wiki.jikexueyuan.com/project/openresty-best-practice/shared-get-keys.html

# Other Data Storage Mechanisms

Use data storage mechanisms such as memcached, redis, MySQL or PostgreSQL. The ngx_openresty bundle associated with this module comes with a set of companion Nginx modules and Lua libraries that provide interfaces with these data storage mechanisms.

## Scope 
cross worker processes

- can be accessed everywhere by using corresponding database API
- expensive cost to access outer database


# LRU cache

https://github.com/openresty/lua-resty-lrucache

## Scope 
single worker process, cross requests

- LRU
- cache operation won't block, but don't execute block operations(ex: os.execute("sleep")) between cache operations


# Required Module 

Use Lua 'require' to load module to global 'package.load' table.

## Scope 
single worker process, cross requests

- Prefer to share read-only data in module
- Changable data can be shared in proper write operations. Don't hand control back to event module between write operation and read operation. ex:
<pre><code>local tmp = module.get(key)
	module.set(key, module.get(key) + 1)
    -- Hand control back to event module here. Event module may receive another request and add 1.
    ngx.sleep(1)
    -- The value will be unpredictable because the worker process may handle other requests and module.get(key) 
    -- increase several times until the non-block sleep end.
    if module.get(key) - 1 == tmp
    	... -- Code here may not execute.
    end
</code></pre>

## Test Process

1. use luajit to compile lua script to bytescode  
	```
	luajit -bg data.lua data.o
	```
2. static link lua module to nginx  
	```
	./configure --with-ld-opt="/path/to/data.o" ...
	```
3. use module in nginx.conf
<pre><code>
    location /lua_test {
	    default_type 'text/plain';
	    content_by_lua '
	        local data_module = require "data"
	        ngx.say("my dog age :", data_module.get_age("dog"))
	        data_module.set_age("dog", data_module.get_age("dog")+1)
	        os.execute("sleep 3")
	        ngx.say("after a year, my dog age :", data_module.get_age("dog"))
	    ';
	}
</code></pre>
5. Test scope by using this line 
    ```os.execute("sleep 3")```  
   os.execute("sleep ..") will let the whole worker process sleep so the incoming request will be handle by 
   other worker processes.  

   **Please set worker_processes > 1 in nginx.conf**  

   Result will be 
   ```
$ curl http://127.0.0.1/lua_test
my dog age :3
after a year, my dog age :4
$ curl http://127.0.0.1/lua_test
my dog age :3
after a year, my dog age :4
$ curl http://127.0.0.1/lua_test
my dog age :4
after a year, my dog age :5
$ curl http://127.0.0.1/lua_test
my dog age :4
after a year, my dog age :5
$ curl http://127.0.0.1/lua_test
my dog age :3
after a year, my dog age :4
$ curl http://127.0.0.1/lua_test
my dog age :5
after a year, my dog age :6
$ curl http://127.0.0.1/lua_test
my dog age :5
after a year, my dog age :6

   ```
   You will see the variable can't cross worker processes to shared.
   Every worker process own a copy of the module.

# ngx.ctx

## Scope
single request, cross phases

- every request owns ctx table (include subrequest)
- internal redirection will destroy original ctx table and create a new one
- should always used in function scope
- expensive cost when get/set this table

# ngx.var

## Scope
single request, cross phases

- can be access in the conf
- expensive cost when get/set this table

```
When reading from an Nginx variable, Nginx will allocate memory in the per-request memory pool which is freed only at request termination. So when you need to read from an Nginx variable repeatedly in your Lua code, cache the Nginx variable value to your own Lua variable, for example,

 local val = ngx.var.some_var
 --- use the val repeatedly later
to prevent (temporary) memory leaking within the current request's lifetime. Another way of caching the result is to use the ngx.ctx table.
```


## DON'T USE GLOBAL VARIABLES IN LUA

Generally, use of Lua global variables is a really really bad idea in the context of ngx_lua because

- misuse of Lua globals has very bad side effects for concurrent requests when these variables are actually supposed to be local only,
- Lua global variables require Lua table look-up in the global environment (which is just a Lua table), which is kinda expensive
- some Lua global variable references are just typos, which are hard to debug.

Use tool lua-releng to scan if global variables exist

https://github.com/openresty/nginx-devel-utils/blob/master/lua-releng

