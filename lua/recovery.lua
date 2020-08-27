local cjson = require "cjson"
local jwt = require "resty.jwt"

ngx.req.read_body()

-- verify token
local token = ngx.var['http_authorization']
token = jwt:verify(os.getenv("JWT_KEY"), token and token:sub(8) or '')
if not (token.verified and token.valid) then
    ngx.status = 403
    ngx.say(("'exp' claim expired" == token.reason:sub(1, 19)) and "jwt expired" or (token.reason and token.reason or "invalid token"))
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- validate token payload
if token["payload"]["state"] ~= "active" or token["payload"]["action"] ~= "email" then
    ngx.status = 403
    ngx.say("incorrect token")
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- todo: attempt counter, no more than 3 requests per day

-- get user info by email and password
local http = require "resty.http"
local response, err = http.new():request_uri("http://127.0.0.1:8080/recovery", {
    method = "POST",
    body = cjson.encode({
        email = token["payload"]["email"],
        baseUrl = ngx.var.scheme..'://'..ngx.var.http_host,
        token = jwt:sign(os.getenv("JWT_KEY"), {
            header = {
                typ = "JWT",
                alg = "HS256"
            },
            payload = {
                email = token["payload"]["email"],
                type = "recovery",
                exp = os.time() + 24 * 3600,
            }
        })
    })
})

if err or response.status ~= 200 then
    ngx.status = response.status
    ngx.say(response.body)
    ngx.exit(response.status)
end

ngx.status = 200
ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(response.body)
ngx.exit(ngx.HTTP_OK)
