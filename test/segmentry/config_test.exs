defmodule Segmentry.ConfigTest do
  use ExUnit.Case, async: false

  alias Segmentry.Config

  setup do
    snapshot = Application.get_all_env(:segmentry)
    on_exit(fn -> reset_env(snapshot) end)
    :ok
  end

  describe "defaults" do
    test "api_url defaults to segment.io" do
      Application.delete_env(:segmentry, :api_url)
      assert Config.api_url() == "https://api.segment.io/v1/"
    end

    test "service defaults to Batcher" do
      Application.delete_env(:segmentry, :sender_impl)
      assert Config.service() == Segmentry.Analytics.Batcher
    end

    test "max_batch_size defaults to 100" do
      Application.delete_env(:segmentry, :max_batch_size)
      assert Config.max_batch_size() == 100
    end

    test "batch_every_ms defaults to 2000" do
      Application.delete_env(:segmentry, :batch_every_ms)
      assert Config.batch_every_ms() == 2000
    end

    test "send_to_http defaults to true" do
      Application.delete_env(:segmentry, :send_to_http)
      assert Config.send_to_http() == true
    end

    test "retry_attempts defaults to 3" do
      Application.delete_env(:segmentry, :retry_attempts)
      assert Config.retry_attempts() == 3
    end

    test "retry_expiry defaults to 10_000" do
      Application.delete_env(:segmentry, :retry_expiry)
      assert Config.retry_expiry() == 10_000
    end

    test "retry_start defaults to 100" do
      Application.delete_env(:segmentry, :retry_start)
      assert Config.retry_start() == 100
    end

    test "req_options defaults to []" do
      Application.delete_env(:segmentry, :req_options)
      assert Config.req_options() == []
    end
  end

  describe "overrides" do
    test "respect application env" do
      Application.put_env(:segmentry, :api_url, "https://eu1.segmentapis.com/v1/")
      Application.put_env(:segmentry, :sender_impl, Segmentry.Analytics.Sender)
      Application.put_env(:segmentry, :max_batch_size, 7)
      Application.put_env(:segmentry, :batch_every_ms, 9)
      Application.put_env(:segmentry, :send_to_http, false)
      Application.put_env(:segmentry, :retry_attempts, 5)
      Application.put_env(:segmentry, :retry_expiry, 99)
      Application.put_env(:segmentry, :retry_start, 11)
      Application.put_env(:segmentry, :req_options, receive_timeout: 1000)

      assert Config.api_url() == "https://eu1.segmentapis.com/v1/"
      assert Config.service() == Segmentry.Analytics.Sender
      assert Config.max_batch_size() == 7
      assert Config.batch_every_ms() == 9
      assert Config.send_to_http() == false
      assert Config.retry_attempts() == 5
      assert Config.retry_expiry() == 99
      assert Config.retry_start() == 11
      assert Config.req_options() == [receive_timeout: 1000]
    end
  end

  defp reset_env(snapshot) do
    snapshot_keys = Keyword.keys(snapshot)

    Enum.each(Application.get_all_env(:segmentry), fn {k, _} ->
      Application.delete_env(:segmentry, k)
    end)

    Enum.each(snapshot_keys, fn k ->
      Application.put_env(:segmentry, k, Keyword.fetch!(snapshot, k))
    end)
  end
end
