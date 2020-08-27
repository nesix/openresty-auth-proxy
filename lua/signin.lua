local cjson = require "cjson"
local jwt = require "resty.jwt"

ngx.req.read_body()

-- read password
local success, requestBody = pcall(cjson.decode, ngx.var.request_body)
if not success or not requestBody["password"] or requestBody["password"] == "" then
    ngx.status = 400
    ngx.say("empty password")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

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

-- get user info by email and password
local http = require "resty.http"
local response, err = http.new():request_uri("http://127.0.0.1:8080/signIn", {
    method = "POST",
    body = cjson.encode({
        email = token["payload"]["email"],
        password = requestBody["password"]
    })
})
if err or response.status ~= 200 then
    ngx.status = response.status
    ngx.say(response.body)
    ngx.exit(response.status)
end

-- decode user info
local success, userInfo = pcall(cjson.decode, response.body)
if not success then
    ngx.status = 500
    ngx.say("api error")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- make response
require "nginx/auth/send_user_tokens"(
    userInfo["id"],
    require "nginx/auth/sha2"(response.body.."-"..os.time()),
    userInfo["role"] or "role"
)
