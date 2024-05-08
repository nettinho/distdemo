defmodule DistdemoWeb.HomeLive do
  use DistdemoWeb, :live_view

  alias Distdemo.Processor

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Distdemo.PubSub, "messages")
      :net_kernel.monitor_nodes(true)
    end

    nodes =
      Node.list()
      |> Enum.map(fn node ->
        node
        |> call_processor(:info)
        |> case do
          {:badrpc, _} -> %{id: node, disconnected: true}
          info -> info
        end
      end)

    my_node = Processor.info()

    {:ok, stream(socket, :nodes, [my_node | nodes])}
  end

  @impl true
  def handle_event("kill_node", %{"node" => node}, socket) do
    :rpc.call(String.to_existing_atom(node), System, :stop, [])
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear", %{"node" => node}, socket) do
    call_processor(node, :clear)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_config", %{"node" => node, "value" => value, "prop" => prop}, socket) do
    call_processor(node, :config, [String.to_existing_atom(prop), value])
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_task", _, socket) do
    Processor.put(:rand.uniform(99))
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_n_tasks", %{"count" => count}, socket) do
    Enum.each(1..String.to_integer(count), fn _ -> Processor.put(:rand.uniform(99)) end)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_all", _, socket) do
    call_all_nodes(:clear)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_all_config", %{"value" => value, "prop" => prop}, socket) do
    call_all_nodes(:config, [String.to_existing_atom(prop), value])
    {:noreply, socket}
  end

  @impl true
  def handle_info({:nodedown, node}, socket) do
    {:noreply, stream_delete(socket, :nodes, %{id: node})}
  end

  def handle_info({:nodeup, node}, socket) do
    node = call_processor(node, :info)
    {:noreply, stream_insert(socket, :nodes, node)}
  end

  def handle_info({:update, node}, socket) do
    {:noreply, stream_insert(socket, :nodes, node)}
  end

  def handle_info(msg, socket) do
    dbg({:recibimos, msg})
    {:noreply, socket}
  end

  defp call_all_nodes(fun, args \\ []) do
    Node.list()
    |> Kernel.++([Node.self()])
    |> Enum.each(&call_processor(&1, fun, args))
  end

  defp call_processor(node, fun, args \\ [])

  defp call_processor(node, fun, args) when is_atom(node) do
    :rpc.call(node, Processor, fun, args)
  end

  defp call_processor(node, fun, args) do
    call_processor(String.to_existing_atom(node), fun, args)
  end
end
