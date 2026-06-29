import Config

config :segmentry,
  sender_impl: Segmentry.Analytics.Batcher,
  max_batch_size: 100,
  batch_every_ms: 5000

config :segmentry,
  retry_attempts: 3,
  retry_expiry: 10_000,
  retry_start: 100

import_config "#{config_env()}.exs"
