# http2-gun
HTTP2 realisation gun library
## Configuration

```
config :http2_gun,
  default_hostname: "example.org",
  default_port: 443,
  max_requests: 4,
  warming_up_count: 4,
  max_connections: 100,
  time_for_timeout: 1000
```
## Example

```
result = HTTP2Gun.request(:get, "http://example.org:443/", "", [])

```