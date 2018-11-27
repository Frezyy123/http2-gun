use Mix.Config


config :http2_gun,
  default_hostname: "zeroloader.xyz",
  default_port: 443,
  max_requests: 100,
  warming_up_count: 4,
  max_connections: 100
