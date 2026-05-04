defmodule Segmentry.Http.StubTest do
  use ExUnit.Case, async: true

  alias Segmentry.Http.Stub

  test "returns a 200 Req.Response without making a real HTTP call" do
    request = Req.new()
    assert {%Req.Request{}, %Req.Response{status: 200, body: ""}} = Stub.call(request)
  end

  test "is selected automatically when send_to_http is false" do
    previous = Application.get_env(:segmentry, :send_to_http)

    try do
      Application.put_env(:segmentry, :send_to_http, false)
      client = Segmentry.Http.client("k")
      event = %Segmentry.Analytics.Track{userId: "u", event: "via stub"}
      assert :ok = Segmentry.Http.send(client, event)
    after
      Application.put_env(:segmentry, :send_to_http, previous)
    end
  end
end
