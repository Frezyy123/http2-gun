use Mix.Config


config :http2_gun,
  default_hostname: "example_org",
  max_requests: 100,
  warming_up_count: 4
