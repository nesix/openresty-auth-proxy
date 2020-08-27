local cjson = require "cjson"
local jwt = require "resty.jwt"

return function (id, sid, role, start)

    local time = os.time()

    local access = jwt:sign(os.getenv("JWT_KEY"), {
        header = {
            typ = "JWT",
            alg = "HS256"
        },
        payload = {
            id = id,
            sid = sid,
            role = role,
            type = "access",
            exp = time + 300
        }
    })

    local refreshExpire = 45 * 24 * 3600
    local refresh = jwt:sign(os.getenv("JWT_KEY"), {
        header = {
            typ = "JWT",
            alg = "HS256"
        },
        payload = {
            id = id,
            sid = sid,
            role = role,
            type = "refresh",
            exp = time + refreshExpire
        }
    })

    local redis = require "nginx/auth/redis"
    local res, err = redis.set('sessions:'..id..':'..sid, cjson.encode{
        ip = ngx.var.http_x_forwarded_for and ngx.var.http_x_forwarded_for or ngx.var.REMOTE_ADDR,
        agent = ngx.var.http_user_agent,
        host = ngx.var.http_host,
        start = start and start or time,
        lastRefresh = time,
        refresh = refresh
    }, refreshExpire)
    if not res then
        ngx.status = 401
        ngx.say(err and err or 'redis error')
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.header["Set-Cookie"] = "refresh="..refresh.."; Path=/api/refresh; HttpOnly; SameSite=Strict; Max-Age="..refreshExpire
    ngx.say(cjson.encode{
        sid = sid,
        access = access
    })
    ngx.exit(ngx.HTTP_OK)

end