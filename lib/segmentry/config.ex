defmodule Segmentry.Config do
  @moduledoc false

  def api_url do
    Application.get_env(:segmentry, :api_url, "https://api.segment.io/v1/")
  end

  def service do
    Application.get_env(:segmentry, :sender_impl, Segmentry.Analytics.Batcher)
  end

  def max_batch_size do
    Application.get_env(:segmentry, :max_batch_size, 100)
  end

  def batch_every_ms do
    Application.get_env(:segmentry, :batch_every_ms, 2000)
  end

  def send_to_http do
    Application.get_env(:segmentry, :send_to_http, true)
  end

  def retry_attempts do
    Application.get_env(:segmentry, :retry_attempts, 3)
  end

  def retry_expiry do
    Application.get_env(:segmentry, :retry_expiry, 10_000)
  end

  def retry_start do
    Application.get_env(:segmentry, :retry_start, 100)
  end

  @doc """
  Extra keyword options merged into every `Req` client. Useful for injecting a
  `:plug` for `Req.Test` stubbing or overriding `:receive_timeout`, etc.
  """
  def req_options do
    Application.get_env(:segmentry, :req_options, [])
  end
end
