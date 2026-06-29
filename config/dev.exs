import Config

# In development, don't make real calls to Segment. With `:send_to_http` false,
# the no-op adapter (`Segmentry.Http.Noop`) logs each request at `:debug` and
# replies `200` instead of hitting the network. Flip to `true` to exercise the
# real HTTP path locally.
config :segmentry, send_to_http: false
