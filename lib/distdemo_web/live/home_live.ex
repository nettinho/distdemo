defmodule DistdemoWeb.HomeLive do
  use DistdemoWeb, :live_view

  @impl true
  def mount(_, _, socket) do
    # {_monref, nodes} = :pg.monitor(:super_cluster) |> dbg

    if connected?(socket), do: :net_kernel.monitor_nodes(true)

    nodes = Node.list() |> Enum.map(&%{id: &1}) |> dbg

    {:ok,
     socket
     |> assign(my_node: Node.self())
     |> stream(:nodes, nodes)}
  end

  @impl true
  def handle_event("kill_node", %{"node" => node}, socket) do
    :rpc.call(String.to_existing_atom(node), System, :stop, [])
    {:noreply, socket}
  end

  @impl true
  def handle_info({:nodedown, node}, socket) do
    dbg({:nodedown, node})
    {:noreply, stream_delete(socket, :nodes, %{id: node})}
  end

  def handle_info({:nodeup, node}, socket) do
    dbg({:nodeup, node})
    {:noreply, stream_insert(socket, :nodes, %{id: node})}
  end

  def handle_info(msg, socket) do
    dbg({:recibimos, msg})
    {:noreply, socket}
  end
end
