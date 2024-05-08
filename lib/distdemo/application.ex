defmodule Distdemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:distdemo, :topologies)

    [
      local: [
        strategy: Elixir.Cluster.Strategy.LocalEpmd
      ]
    ]

    children = [
      Distdemo.Processor,
      DistdemoWeb.Telemetry,
      {Phoenix.PubSub, name: Distdemo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Distdemo.Finch},
      # Start a worker by calling: Distdemo.Worker.start_link(arg)
      # {Distdemo.Worker, arg},
      # Start to serve requests, typically the last entry
      DistdemoWeb.Endpoint,
      {Cluster.Supervisor,
       [
         [
           local: [
             strategy: Elixir.Cluster.Strategy.LocalEpmd
           ]
         ],
         [name: Distdemo.ClusterSupervisor]
       ]}
      # %{id: :pg, start: {:pg, :start_link, []}},
    ]

    Node.set_cookie(:cookie)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      name: Distdemo.Supervisor,
      distributed: true
    ]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DistdemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
