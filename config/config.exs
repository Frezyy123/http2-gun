use Mix.Config


config :http2_gun,
  default_hostname: "duckduckgo.com",
  default_port: 443,
  max_requests: 10,
  warming_up_count: 4,
  max_connections: 50
