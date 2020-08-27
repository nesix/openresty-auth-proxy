local cjson = require "cjson"
local jwt = require "resty.jwt"
local lostAuthorization = require "nginx/auth/lost_authorization"
local redis = require "nginx/auth/redis"

ngx.req.read_body()

-- read sid
local success, requestBody = pcall(cjson.decode, ngx.var.request_body)
if not success or not requestBody["sid"] or requestBody["sid"] == "" then
    ngx.status = 400
    ngx.say("bad request")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- verify token
local refresh = ngx.var["cookie_refresh"]
local token = jwt:verify(os.getenv("JWT_KEY"), refresh)
if not (token.verified and token.valid) then
    lostAuthorization("invalid token")
end

-- token validation
token = token['payload']
if token['type'] ~= 'refresh' and token['sid'] ~= requestBody["sid"] then
    lostAuthorization("payload")
end

local id = token["id"]
local sid = token["sid"]
local role = token["role"]

local redisData = redis.get('sessions:'..id..':'..sid)
if not redisData then
    lostAuthorization("redis empty")
end

local success, redisData = pcall(cjson.decode, redisData)
if not success then
    lostAuthorization("decode error")
end

if redisData["refresh"] ~= refresh then
    lostAuthorization(cjson.encode{
        refresh = refresh,
        redis = redisData["refresh"],
        key = 'sessions:'..id..':'..sid
    })
end

require "nginx/auth/send_user_tokens"(
    id,
    sid,
    role,
    redisData['start']
)
