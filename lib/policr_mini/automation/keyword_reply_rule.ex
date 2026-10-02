defmodule PolicrMini.Automation.KeywordReplyRule do
  use PolicrMini.Schema

  @fields ~w(chat_id keyword keywords match_mode case_sensitive enabled response_text buttons)a
  @max_buttons 8
  @max_keywords 50

  schema "keyword_reply_rules" do
    field :chat_id, :integer
    field :keyword, :string
    field :keywords, {:array, :string}, default: []
    field :match_mode, :string, default: "contains"
    field :case_sensitive, :boolean, default: false
    field :enabled, :boolean, default: true
    field :response_text, :string
    field :buttons, {:array, :map}, default: []
    timestamps()
  end

  def changeset(rule, attrs) do
    attrs = normalize_keywords(attrs)

    rule
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :keyword, :keywords, :response_text])
    |> validate_keyword_list_present()
    |> update_change(:keyword, &String.trim/1)
    |> update_change(:response_text, &String.trim/1)
    |> validate_length(:keyword, min: 1, max: 200)
    |> validate_change(:keywords, &validate_keywords/2)
    |> validate_length(:response_text, min: 1, max: 4_096)
    |> validate_inclusion(:match_mode, ~w(contains exact prefix))
    |> validate_change(:buttons, &validate_buttons/2)
    |> unique_constraint([:chat_id, :keywords, :match_mode, :case_sensitive],
      name: :keyword_reply_rules_keywords_identity_index
    )
  end

  defp normalize_keywords(attrs) when is_map(attrs) do
    string_keys? = Enum.any?(Map.keys(attrs), &is_binary/1)
    keyword_key = if string_keys?, do: "keyword", else: :keyword
    keywords_key = if string_keys?, do: "keywords", else: :keywords

    legacy_keyword = Map.get(attrs, keyword_key)

    keywords =
      case Map.get(attrs, keywords_key) do
        values when is_list(values) -> values
        value when is_binary(value) -> String.split(value, ~r/\r?\n/)
        _ -> [legacy_keyword]
      end
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    attrs
    |> Map.put(keywords_key, keywords)
    |> Map.put(keyword_key, List.first(keywords) || "")
  end

  defp validate_keywords(:keywords, keywords) when is_list(keywords) do
    cond do
      keywords == [] ->
        [keywords: "must contain at least one keyword"]

      length(keywords) > @max_keywords ->
        [keywords: "supports at most #{@max_keywords} keywords"]

      Enum.any?(keywords, &(String.length(&1) not in 1..200)) ->
        [keywords: "each keyword must contain 1 to 200 characters"]

      true ->
        []
    end
  end

  defp validate_keywords(:keywords, _keywords), do: [keywords: "must be a list"]

  defp validate_keyword_list_present(changeset) do
    if get_field(changeset, :keywords) == [] do
      add_error(changeset, :keywords, "must contain at least one keyword")
    else
      changeset
    end
  end

  defp validate_buttons(:buttons, buttons) when is_list(buttons) do
    cond do
      length(buttons) > @max_buttons ->
        [buttons: "supports at most #{@max_buttons} buttons"]

      Enum.all?(buttons, &valid_button?/1) ->
        []

      true ->
        [buttons: "must contain button text and a valid http, https, or tg URL"]
    end
  end

  defp validate_buttons(:buttons, _buttons), do: [buttons: "must be a list"]

  defp valid_button?(button) when is_map(button) do
    text = Map.get(button, "text", Map.get(button, :text))
    url = Map.get(button, "url", Map.get(button, :url))

    is_binary(text) and String.length(String.trim(text)) in 1..64 and is_binary(url) and
      String.length(url) <= 2_048 and valid_url?(url)
  end

  defp valid_button?(_button), do: false

  defp valid_url?(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] ->
        is_binary(host) and host != ""

      %URI{scheme: "tg", host: host, path: path} ->
        (is_binary(host) and host != "") or (is_binary(path) and path != "")

      _ ->
        false
    end
  end
end
