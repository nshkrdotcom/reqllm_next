%{
  deps: %{
    execution_plane: %{
      path: "../execution_plane/core/execution_plane",
      github: %{repo: "nshkrdotcom/execution_plane", branch: "main", subdir: "core/execution_plane"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_http: %{
      path: "../execution_plane/protocols/execution_plane_http",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "protocols/execution_plane_http"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_sse: %{
      path: "../execution_plane/streaming/execution_plane_sse",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "streaming/execution_plane_sse"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_websocket: %{
      path: "../execution_plane/streaming/execution_plane_websocket",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "streaming/execution_plane_websocket"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
