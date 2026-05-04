defmodule SegmentryTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics.Track

  setup do
    Segmentry.FakeSender.install()
    :ok
  end

  test "start_link/1 delegates to the configured service" do
    {:ok, _pid} = Segmentry.start_link("k")
  end

  test "start_link/2 delegates to the configured service" do
    {:ok, _pid} = Segmentry.start_link("k", [])
  end

  test "child_spec/1 delegates to the configured service" do
    spec = Segmentry.child_spec(nil)
    assert spec.id == Segmentry.FakeSender
  end

  test "Analytics.* delegates through the configured service" do
    :ok = Segmentry.Analytics.track("u", "Hello")
    assert_received {:fake_sender, %Track{userId: "u", event: "Hello"}}
  end
end
