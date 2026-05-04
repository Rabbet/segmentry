defmodule Segmentry.AnalyticsTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics
  alias Segmentry.Analytics.{Track, Identify, Alias, Page, Screen, Group, Context}

  setup do
    Segmentry.FakeSender.install()
    :ok
  end

  describe "send/1" do
    test "routes any known event struct" do
      assert :ok = Analytics.send(%Track{userId: "u", event: "e"})
      assert_received {:fake_sender, %Track{userId: "u", event: "e"}}
    end
  end

  describe "track" do
    test "track/4 builds a Track struct" do
      :ok = Analytics.track("u", "Sign Up", %{plan: "pro"})

      assert_received {:fake_sender,
                       %Track{userId: "u", event: "Sign Up", properties: %{plan: "pro"}}}
    end

    test "track/1 passes the struct through" do
      t = %Track{userId: "u", event: "e"}
      :ok = Analytics.track(t)
      assert_received {:fake_sender, ^t}
    end
  end

  describe "identify" do
    test "identify/3 builds an Identify struct" do
      :ok = Analytics.identify("u", %{name: "M"})
      assert_received {:fake_sender, %Identify{userId: "u", traits: %{name: "M"}}}
    end

    test "identify/1 passes the struct through" do
      i = %Identify{userId: "u", traits: %{name: "M"}}
      :ok = Analytics.identify(i)
      assert_received {:fake_sender, ^i}
    end
  end

  describe "screen" do
    test "screen/4 builds a Screen struct" do
      :ok = Analytics.screen("u", "Home", %{section: "top"})
      assert_received {:fake_sender, %Screen{userId: "u", name: "Home"}}
    end

    test "screen/1 passes the struct through" do
      s = %Screen{userId: "u", name: "Home"}
      :ok = Analytics.screen(s)
      assert_received {:fake_sender, ^s}
    end
  end

  describe "alias" do
    test "alias/3 builds an Alias struct" do
      :ok = Analytics.alias("u2", "u1")
      assert_received {:fake_sender, %Alias{userId: "u2", previousId: "u1"}}
    end

    test "alias/1 passes the struct through" do
      a = %Alias{userId: "u2", previousId: "u1"}
      :ok = Analytics.alias(a)
      assert_received {:fake_sender, ^a}
    end
  end

  describe "group" do
    test "group/4 builds a Group struct" do
      :ok = Analytics.group("u", "g", %{plan: "pro"})
      assert_received {:fake_sender, %Group{userId: "u", groupId: "g", traits: %{plan: "pro"}}}
    end

    test "group/1 passes the struct through" do
      g = %Group{userId: "u", groupId: "g"}
      :ok = Analytics.group(g)
      assert_received {:fake_sender, ^g}
    end
  end

  describe "page" do
    test "page/4 builds a Page struct" do
      :ok = Analytics.page("u", "Home", %{section: "top"})
      assert_received {:fake_sender, %Page{userId: "u", name: "Home"}}
    end

    test "page/1 passes the struct through" do
      p = %Page{userId: "u", name: "Home"}
      :ok = Analytics.page(p)
      assert_received {:fake_sender, ^p}
    end
  end

  test "default context is attached when not supplied" do
    :ok = Analytics.track("u", "e")
    assert_received {:fake_sender, %Track{context: %Context{} = ctx}}
    assert ctx.library.name == "Elixir client for Segment, built on Req"
  end
end
