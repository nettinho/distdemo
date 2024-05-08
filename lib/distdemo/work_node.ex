defmodule Distdemo.WorkNode do
  defstruct [
    :id,
    queue: [],
    history: [],
    running: nil,
    queue_delay: 1000,
    run_delay: 5000
  ]
end
