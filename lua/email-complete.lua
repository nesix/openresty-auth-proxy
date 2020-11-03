local cjson = require "cjson"
local jwt = require "resty.jwt"


-- verify token
local token = ngx.var['http_authorization']
token = jwt:verify(os.getenv("JWT_KEY"), token and token:sub(8) or '')
if not (token.verified and token.valid) then
    ngx.status = 403
    ngx.say(("'exp' claim expired" == token.reason:sub(1, 19)) and "jwt expired" or (token.reason and token.reason or "invalid token"))
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- validate token payload
if not (token["payload"]["type"] == "registration" or token["payload"]["type"] == "recovery" or token["payload"]["type"] == "change") then
    ngx.status = 403
    ngx.say("incorrect token")
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

local password

if token["payload"]["type"] == "recovery" then

    ngx.req.read_body()

    -- read name and password
    local success, requestBody = pcall(cjson.decode, ngx.var.request_body)
    if not success then
        ngx.status = 400
        ngx.say("bad request")
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    if not requestBody["password"] or requestBody["password"] == "" then
        ngx.status = 400
        ngx.say("empty password")
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    password = requestBody["password"]

end

-- send request
local http = require "resty.http"
local response, err = http.new():request_uri("http://127.0.0.1:8080/email-complete", {
    method = "POST",
    body = cjson.encode({
        email = token["payload"]["email"],
        type = token["payload"]["type"],
        uid = token["payload"]["uid"],
        password = password,
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
