local cjson = require "cjson"
local jwt = require "resty.jwt"
local lostAuthorization = require "nginx/auth/lost_authorization"
local redis = require "nginx/auth/redis"

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

local redisData = redis.get('sessions:'..id..':'..sid)
if not redisData then
    ngx.status = 403
    ngx.say('session error')
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

ngx.req.set_header("X-User-Id", id)
ngx.req.set_header("X-User-Session-Id", sid)
