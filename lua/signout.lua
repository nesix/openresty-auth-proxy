local cjson = require "cjson"
local jwt = require "resty.jwt"
local redis = require "nginx/auth/redis"

ngx.req.read_body()

-- verify token
local token = ngx.var['http_authorization']
token = jwt:verify(os.getenv("JWT_KEY"), token and token:sub(8) or '')
if not (token.verified and token.valid and token.payload['type'] == 'access') then
    ngx.status = 403
    ngx.say(("'exp' claim expired" == token.reason:sub(1, 19)) and "jwt expired" or (token.reason and token.reason or "invalid token"))
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- read sid (optional)
local success, requestBody = pcall(cjson.decode, ngx.var.request_body)

local requestSid = requestBody["sid"]

local ans, err = redis.del('sessions:'..token.payload['id']..':'..(requestBody["sid"] and requestBody["sid"] or token.payload['sid']))

if not requestBody["sid"] or requestBody["sid"] == token.payload['sid'] then
    ngx.header["Set-Cookie"] = "refresh=; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
end

ngx.exit(ngx.HTTP_OK)
