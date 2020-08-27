local redis = {}

function redis.mgetByMask (mask)
    local red = require "resty.redis":new()
    red:set_timeouts(10000, 5000, 5000)
    local ok, err = red:connect(os.getenv('REDIS_SERVER'), os.getenv('REDIS_PORT'))
    if not ok then
        return nil, nil
    end
    local keys, err = red:keys(mask)
    if err or not keys then
        return nil, nil
    end
    local values, err = red:mget(table.unpack(keys))
    if not values or values == ngx.null then
        return nil, nil
    else
        return values, keys
    end
end

function redis.get (key)
    local red = require "resty.redis":new()
    red:set_timeouts(10000, 5000, 5000)
    local ok, err = red:connect(os.getenv('REDIS_SERVER'), os.getenv('REDIS_PORT'))
    if not ok then
        return nil
    end
    local data = red:get(key)
    if not data or data == ngx.null then
        return nil
    else
        return data
    end
end

function redis.set (key, value, expire)
    local red = require "resty.redis":new()
    red:set_timeouts(10000, 5000, 5000)
    local ok, err = red:connect(os.getenv('REDIS_SERVER'), os.getenv('REDIS_PORT'))
    if not ok then
        return nil, err and err or 'connect'
    end
    local ans, err = red:set(key, value)
    if not ans or ans == ngx.null then
        return nil, err and err or 'set'
    else
        if expire then
            red:expire(key, expire)
        end
        return ans, nil
    end
end

function redis.del (key)
    local red = require "resty.redis":new()
    red:set_timeouts(10000, 5000, 5000)
    local ok, err = red:connect(os.getenv('REDIS_SERVER'), os.getenv('REDIS_PORT'))
    if not ok then
        return nil, err and err or 'connect'
    end
    local ans, err = red:del(key)
    if not ans or ans == ngx.null then
        return nil, err and err or 'set'
    else
        return ans, nil
    end
end

return redis