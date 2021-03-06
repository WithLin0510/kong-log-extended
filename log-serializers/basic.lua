local tablex = require "pl.tablex"

local _M = {}

local tcp_log_extended_ctx = ngx.ctx.tcp_log_extended or {}
local udp_log_extended_ctx = ngx.ctx.udp_log_extended or {}
local file_log_extended_ctx = ngx.ctx.file_log_extended or {}
local sys_log_extended_ctx = ngx.ctx.sys_log_extended or {}

local EMPTY = tablex.readonly({})

function _M.serialize(ngx)
  local authenticated_entity
  if ngx.ctx.authenticated_credential ~= nil then
    authenticated_entity = {
      id = ngx.ctx.authenticated_credential.id,
      consumer_id = ngx.ctx.authenticated_credential.consumer_id
    }
  end
   
  return {
    request = {
      uri = ngx.var.request_uri,
      url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
      querystring = ngx.req.get_uri_args(), -- parameters, as a table
      method = ngx.req.get_method(), -- http method
      headers = ngx.req.get_headers(),
      size = ngx.var.request_length,
      tcp_log_extended_body = tcp_log_extended_ctx.req_body,
      udp_log_extended_body = udp_log_extended_ctx.req_body,
      file_log_extended_body = file_log_extended_ctx.req_body,
      sys_log_extended_body = sys_log_extended_ctx.req_body,
    },
    upstream_uri = ngx.var.upstream_uri,
    response = {
      status = ngx.status,
      headers = ngx.resp.get_headers(),
      size = ngx.var.bytes_sent,
      tcp_log_extended_body = tcp_log_extended_ctx.res_body,
      udp_log_extended_body = udp_log_extended_ctx.res_body,
      file_log_extended_body = file_log_extended_ctx.res_body,
      sys_log_extended_body = sys_log_extended_ctx.res_body
    },
    tries = (ngx.ctx.balancer_address or EMPTY).tries,
    latencies = {
      kong = (ngx.ctx.KONG_ACCESS_TIME or 0) +
             (ngx.ctx.KONG_RECEIVE_TIME or 0) +
             (ngx.ctx.KONG_REWRITE_TIME or 0) +
             (ngx.ctx.KONG_BALANCER_TIME or 0),
      proxy = ngx.ctx.KONG_WAITING_TIME or -1,
      request = ngx.var.request_time * 1000
    },
    authenticated_entity = authenticated_entity,
    api = ngx.ctx.api,
    consumer = ngx.ctx.authenticated_consumer,
    client_ip = ngx.var.remote_addr,
    started_at = ngx.req.start_time() * 1000
  }
end

return _M
