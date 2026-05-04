import Config

config :segmentry,
  send_to_http: true,
  batch_every_ms: 50,
  retry_start: 1,
  retry_expiry: 10
