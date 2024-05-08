defmodule Distdemo.Processor do
  use GenServer

  alias Distdemo.WorkNode

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def info do
    GenServer.call(__MODULE__, :state)
  end

  def put(value) do
    GenServer.cast(__MODULE__, {:put, value})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  def config(prop, value) do
    GenServer.cast(__MODULE__, {:config, prop, value})
  end

  @impl GenServer
  def init(_) do
    %{queue_delay: delay} = state = %WorkNode{id: Node.self()}
    Process.send_after(__MODULE__, :process_queue, delay)
    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:put, value}, %{queue: queue} = state) do
    state
    |> Map.put(:queue, queue ++ [value])
    |> broadcast!()
  end

  def handle_cast({:config, prop, value}, state) do
    state
    |> Map.put(prop, value)
    |> broadcast!()
  end

  @impl true
  def handle_cast(:clear, state) do
    state
    |> Map.put(:history, [])
    |> broadcast!()
  end

  @impl true
  def handle_info(:process_queue, %{queue_delay: delay} = state) do
    Process.send_after(__MODULE__, :process_queue, delay)

    queue_process(state)
  end

  def handle_info(:task_done, %{running: task} = state) do
    state
    |> Map.put(:running, nil)
    |> Map.update!(:history, &(&1 ++ [task]))
    |> broadcast!()
  end

  defp queue_process(%{queue: [task | rest], running: nil, run_delay: delay} = state) do
    Process.send_after(__MODULE__, :task_done, delay)

    state
    |> Map.put(:queue, rest)
    |> Map.put(:running, task)
    |> broadcast!()
  end

  defp queue_process(%{queue: [task | rest]} = state) do
    case Node.list() do
      [] ->
        nil

      list ->
        list
        # |> random_node()
        |> best_node()
        |> then(&:rpc.call(&1.id, __MODULE__, :put, [task]))
    end

    Map.put(state, :queue, rest)
    |> broadcast!()
  end

  defp best_node(list) do
    list
    |> Enum.map(fn node ->
      queue_count =
        node
        |> :rpc.call(__MODULE__, :info, [])
        |> Map.get(:queue)
        |> Enum.count()

      %{id: node, queue_count: queue_count}
    end)
    |> Enum.sort_by(& &1.queue_count)
    |> List.first()
  end

  defp random_node(list) do
    list
    |> Enum.random()
    |> then(&%{id: &1})
  end

  defp queue_process(state), do: {:noreply, state}

  defp broadcast!(state) do
    Phoenix.PubSub.broadcast!(Distdemo.PubSub, "messages", {:update, state})
    {:noreply, state}
  end
end
