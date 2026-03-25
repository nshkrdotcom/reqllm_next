defmodule ReqLlmNext.OpenAI.VideosTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Videos

  test "builds create-video bodies" do
    assert Videos.build_create_body(
             model: "sora-2",
             prompt: "A drone shot of Chicago at sunrise",
             seconds: 8,
             fps: 24
           ) ==
             %{
               model: "sora-2",
               prompt: "A drone shot of Chicago at sunrise",
               seconds: 8,
               fps: 24
             }
  end

  test "builds edit and extension bodies" do
    assert Videos.build_edit_body(video_id: "vid_123", prompt: "Add snowfall") ==
             %{video_id: "vid_123", prompt: "Add snowfall"}

    assert Videos.build_extension_body(video_id: "vid_123", seconds: 4) ==
             %{video_id: "vid_123", seconds: 4}
  end

  test "builds list query paths" do
    assert Videos.build_query_path("/v1/videos", after: "vid_1", limit: 10) ==
             "/v1/videos?after=vid_1&limit=10"
  end
end
