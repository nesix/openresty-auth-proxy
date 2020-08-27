local cjson = require "cjson"
local jwt = require "resty.jwt"

-- verify token
local token = ngx.var['http_authorization']
token = jwt:verify(os.getenv("JWT_KEY"), token and token:sub(8) or '')
if not (token.verified and token.valid and token.payload['type'] == 'access') then
    ngx.status = 403
    ngx.say(("'exp' claim expired" == token.reason:sub(1, 19)) and "jwt expired" or (token.reason and token.reason or "invalid token"))
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

local id = token["payload"]["id"]
local sid = token["payload"]["sid"]

local redis = require "nginx/auth/redis"
local sessions, keys = redis.mgetByMask('sessions:'..id..':*')
if not sessions then
    ngx.status = 403
    ngx.say('session error')
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

for i, v in ipairs(sessions) do
    v = cjson.decode(v)
    local localSid = keys[i]:sub(-64);
    sessions[i] = {
        sid = localSid,
        ip = v.ip,
        agent = v.agent,
        start = v.start,
        time = v.lastRefresh,
        isCurrent = sid == localSid,
    }
end

ngx.header.content_type = "application/json; charset=utf-8"

ngx.say(cjson.encode(sessions))

ngx.exit(ngx.HTTP_OK)