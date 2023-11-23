defmodule PlatformWeb.HTTPDownload do
  def stream!(url) do
    Stream.resource(
      fn -> start_request(url) end,
      fn ref ->
        case receive_response(ref) do
          # returning the chunk to the stream
          {:ok, {:chunk, chunk}} ->
            HTTPoison.stream_next(ref)
            {[chunk], ref}

          {:ok, msg} ->
            # IO.inspect(msg)
            HTTPoison.stream_next(ref)
            {[], ref}

          {:error, error} ->
            # IO.puts("ERROR")
            raise("error #{inspect(error)}")

          :done ->
            {:halt, ref}
        end
      end,
      fn ref -> :hackney.stop_async(ref) end
    )
  end

  defp start_request(url) do
    {:ok, ref} = HTTPoison.get(url, %{}, stream_to: self(), async: :once)
    ref
  end

  defp receive_response(ref) do
    id = ref.id

    receive do
      %HTTPoison.AsyncStatus{code: code, id: ^id} when 200 <= code and code < 300 ->
        {:ok, {:status_code, code}}

      %HTTPoison.AsyncStatus{code: code, id: ^id} ->
        {:error, {:status_code, code}}

      %HTTPoison.AsyncHeaders{headers: headers, id: ^id} ->
        {:ok, {:headers, headers}}

      %HTTPoison.AsyncChunk{chunk: chunk, id: ^id} ->
        {:ok, {:chunk, chunk}}

      %HTTPoison.AsyncEnd{id: ^id} ->
        :done
    end
  end
end
