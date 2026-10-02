defmodule PolicrMiniBot.TelegramText do
  @moduledoc false

  def utf16_slice(text, offset, length) do
    utf16 = :unicode.characters_to_binary(text, :utf8, {:utf16, :little})
    start = min(max(offset * 2, 0), byte_size(utf16))
    available = byte_size(utf16) - start
    bytes = min(max(length * 2, 0), available)

    utf16
    |> binary_part(start, bytes)
    |> :unicode.characters_to_binary({:utf16, :little}, :utf8)
  end

  def utf16_after(text, offset) do
    utf16_length =
      text |> :unicode.characters_to_binary(:utf8, {:utf16, :little}) |> byte_size() |> div(2)

    utf16_slice(text, offset, utf16_length - offset)
  end
end
