return function (type)
    ngx.status = 401
    ngx.say("lost authorization")
    ngx.header["Set-Cookie"] = "refresh=; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    if type then
        ngx.header["X-Lost-Type"] = type
    end
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end