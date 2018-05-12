local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local cjson = require "cjson"

local TcpLogHandler = BasePlugin:extend()

TcpLogHandler.PRIORITY = 7
TcpLogHandler.VERSION = "0.1.0"

local function log(premature, conf, message)
  if premature then
    return
  end

  local ok, err
  local host = conf.host
  local port = conf.port
  local timeout = conf.timeout
  local keepalive = conf.keepalive

  local sock = ngx.socket.tcp()
  sock:settimeout(timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if conf.tls then
    ok, err = sock:sslhandshake(true, conf.tls_sni, false)
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log] failed to perform TLS handshake to ",
                       host, ":", port, ": ", err)
      return
    end
  end

  ok, err = sock:send(cjson.encode(message) .. "\r\n")
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  ok, err = sock:setkeepalive(keepalive)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end
end

local ctx = ngx.ctx
ctx.file_log_extended = { req_body = "", res_body = "" }
if conf.log_bodies then
  req_read_body()
  ctx.file_log_extended.req_body = req_get_body_data()
end


function TcpLogHandler:new()
  TcpLogHandler.super.new(self, "tcp-log")
end

function TcpLogHandler:log(conf)
  TcpLogHandler.super.log(self)

  local message = basic_serializer.serialize(ngx)
  local ok, err = ngx.timer.at(0, log, conf, message)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to create timer: ", err)
  end
end

return TcpLogHandler
