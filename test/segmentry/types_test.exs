defmodule Segmentry.TypesTest do
  use ExUnit.Case, async: true

  alias Segmentry.Analytics.{Track, Identify, Alias, Page, Screen, Group, Context, Types}

  test "common_fields lists the expected keys" do
    assert Types.common_fields() == [
             :anonymousId,
             :context,
             :integrations,
             :timestamp,
             :userId,
             :version
           ]
  end

  describe "event new/1" do
    test "Track" do
      t = Track.new(%{userId: "u", event: "Sign Up", properties: %{plan: "pro"}})
      assert %Track{userId: "u", event: "Sign Up", properties: %{plan: "pro"}, type: "track"} = t
    end

    test "Identify" do
      i = Identify.new(%{userId: "u", traits: %{name: "M"}})
      assert %Identify{userId: "u", traits: %{name: "M"}, type: "identify"} = i
    end

    test "Alias" do
      a = Alias.new(%{userId: "u2", previousId: "u1"})
      assert %Alias{userId: "u2", previousId: "u1", type: "alias"} = a
    end

    test "Page" do
      p = Page.new(%{userId: "u", name: "Home"})
      assert %Page{userId: "u", name: "Home", type: "page"} = p
    end

    test "Screen" do
      s = Screen.new(%{userId: "u", name: "Settings"})
      assert %Screen{userId: "u", name: "Settings", type: "screen"} = s
    end

    test "Group" do
      g = Group.new(%{userId: "u", groupId: "g", traits: %{plan: "pro"}})
      assert %Group{userId: "u", groupId: "g", traits: %{plan: "pro"}, type: "group"} = g
    end
  end

  describe "Context" do
    test "new/0 stamps library name and version" do
      ctx = Context.new()
      assert ctx.library == %{name: "Elixir client for Segment, built on Req", version: "0.3.0"}
    end

    test "new/1 preserves attrs and stamps library" do
      ctx = Context.new(%{active: false, ip: "1.2.3.4"})
      assert ctx.active == false
      assert ctx.ip == "1.2.3.4"
      assert ctx.library.name == "Elixir client for Segment, built on Req"
    end

    test "update/1 overwrites library on an existing struct" do
      stale = %Context{library: %{name: "old", version: "0.0.1"}}
      assert Context.update(stale).library.name == "Elixir client for Segment, built on Req"
    end
  end
end
