local cjson = require "cjson"
local jwt = require "resty.jwt"
local http = require "resty.http"
local httpc = http.new()
local redis = require "nginx/auth/redis"

local recaptcha

ngx.req.read_body()

-- read request
local success, requestBody = pcall(cjson.decode, ngx.var.request_body)
if not success or not requestBody["response"] or requestBody["response"] == "" then
    ngx.status = 400
    ngx.say("invalid payload")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- validate recaptcha
local response, err = httpc:request_uri("https://www.google.com/recaptcha/api/siteverify?secret="..os.getenv("RECAPTCHA_SECRET")..'&response='..requestBody["response"], {
    method = "POST",
    ssl_verify = false
})
if err or response.status ~= 200 then
    ngx.status = 500
    ngx.say("recaptcha error")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- decode recaptcha
success, recaptcha = pcall(cjson.decode, response.body)
if not success then
    ngx.status = 500
    ngx.say("recaptcha error")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- check recaptcha "success"
if not recaptcha.success then
    ngx.status = 403
    ngx.say("failed validation")
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- check recaptcha "action"
if recaptcha.action ~= "userInfo" then
    ngx.status = 400
    ngx.say("incorrect action")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

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

if requestBody["email"] and requestBody["email"] ~= "" then
    requestBody.baseUrl = ngx.var.scheme..'://'..ngx.var.http_host
    requestBody.token = jwt:sign(os.getenv("JWT_KEY"), {
        header = {
            typ = "JWT",
            alg = "HS256"
        },
        payload = {
            uid = id,
            email = requestBody["email"],
            type = "change",
            exp = os.time() + 24 * 3600,
        }
    })
    ngx.req.set_body_data(cjson.encode(requestBody))
end

ngx.req.set_header("X-User-Id", id)
ngx.req.set_header("X-User-Session-Id", sid)
