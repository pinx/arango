defmodule Arango.Command do
  @moduledoc false
  defstruct database: nil,
    method: nil,
    path: nil,
    params: nil,
    meta: nil,
    body: nil,
    opts: nil

end
