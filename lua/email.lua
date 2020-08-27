local cjson = require "cjson"
local jwt = require "resty.jwt"
local http = require "resty.http"
local httpc = http.new()

ngx.req.read_body()

-- read request
local success, requestBody = pcall(cjson.decode, ngx.var.request_body)
if not success or not requestBody["email"] or requestBody["email"] == "" or not requestBody["response"] or requestBody["response"] == "" then
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
if recaptcha.action ~= "email" then
    ngx.status = 400
    ngx.say("incorrect action")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- check email
response, err = httpc:request_uri("http://127.0.0.1:8080/email", {
    method = "POST",
    body = cjson.encode({
        email = requestBody["email"]
    })
})
if err or response.status ~= 200 then
    ngx.status = 500
    ngx.say("email error 1")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- parse email response
success, response = pcall(cjson.decode, response.body)
if not success then
    ngx.status = 500
    ngx.say("email error 2")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- make response
ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(cjson.encode{
    token = jwt:sign(
        os.getenv("JWT_KEY"),
        {
            header = {
                typ = "JWT",
                alg = "HS256"
            },
            payload = {
                email = response["email"],
                state = response["state"],
                action = "email",
                exp = os.time() + 300,
            }
        }
    ),
    state = response["state"]
})
ngx.exit(ngx.HTTP_OK)