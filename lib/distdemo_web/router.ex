defmodule DistdemoWeb.Router do
  use DistdemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DistdemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DistdemoWeb do
    pipe_through :browser

    live "/", HomeLive
  end


  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:distdemo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: DistdemoWeb.Telemetry
    end
  end
end
