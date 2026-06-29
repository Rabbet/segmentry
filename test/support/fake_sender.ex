defmodule Segmentry.FakeSender do
  @moduledoc """
  Test double for `:sender_impl`. Forwards every `call/1` to a pid stored in
  application env under `:fake_sender_listener` so tests can assert on the
  events that were dispatched.
  """

  @listener_key :fake_sender_listener

  def install(listener \\ self()) do
    previous = Application.get_env(:segmentry, :sender_impl)
    Application.put_env(:segmentry, @listener_key, listener)
    Application.put_env(:segmentry, :sender_impl, __MODULE__)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:segmentry, @listener_key)

      case previous do
        nil -> Application.delete_env(:segmentry, :sender_impl)
        impl -> Application.put_env(:segmentry, :sender_impl, impl)
      end
    end)
  end

  def call(event) do
    pid = Application.fetch_env!(:segmentry, @listener_key)
    send(pid, {:fake_sender, event})
    :ok
  end

  # The Segmentry top-level start_link/1,2 will still call this in some tests:
  def start_link(_), do: {:ok, spawn(fn -> :ok end)}
  def start_link(_, _), do: {:ok, spawn(fn -> :ok end)}
  def child_spec(_), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [nil]}}
end
