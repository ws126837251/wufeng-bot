defmodule PolicrMini.ManagementApprovals do
  @moduledoc false

  import Ecto.Query
  import Plug.Conn

  alias PolicrMini.{Accounts, ManagementApproval, Repo}
  alias PolicrMini.Automation.MessageTemplates
  alias PolicrMini.Chats
  alias PolicrMini.Instances.Chat
  alias PolicrMini.Schema.{Permission, User}
  alias Telegex.Type.{ChatMemberOwner, InlineKeyboardButton, InlineKeyboardMarkup}

  @mutating_methods ~w(POST PUT PATCH DELETE)
  @max_response_bytes 2_000

  def mutating_method?(method), do: method in @mutating_methods

  def requester_role(%Plug.Conn{} = conn) do
    with {:ok, chat_id} <- resolve_chat_id(conn),
         {:ok, requester} <- requester(conn),
         {:ok, member} <- Telegex.get_chat_member(chat_id, requester.id) do
      {:ok, member_role(member)}
    else
      {:error, :chat_not_found} = error -> error
      {:error, :requester_not_found} = error -> error
      {:error, _reason} -> {:error, :requester_lookup_failed}
    end
  end

  @doc false
  def member_role(%{status: "creator"}), do: :owner
  def member_role(%{status: "administrator"}), do: :administrator
  def member_role(_member), do: :member

  @doc false
  def approval_required?(:owner), do: false
  def approval_required?(_role), do: true

  def request_http(%Plug.Conn{} = conn) do
    with {:ok, chat_id} <- resolve_chat_id(conn),
         {:ok, chat} <- Chat.get(chat_id),
         {:ok, owner} <- find_owner(chat_id),
         {:ok, requester} <- requester(conn),
         attrs <- request_attrs(conn, chat, owner, requester),
         {:ok, approval, created?} <- insert_or_get_pending(attrs),
         {:ok, approval} <- ensure_notification(approval, chat, owner, requester, created?) do
      {:ok, approval}
    end
  end

  def request_action(chat_id, requester_user_id, method, path, params, action_key, summary) do
    with {:ok, chat} <- Chat.get(chat_id),
         {:ok, owner} <- find_owner(chat.id),
         requester when not is_nil(requester) <- Accounts.get_user(requester_user_id),
         attrs <-
           base_attrs(
             chat.id,
             owner.id,
             requester.id,
             method,
             path,
             params,
             action_key,
             summary
           ),
         {:ok, approval, created?} <- insert_or_get_pending(attrs),
         {:ok, approval} <- ensure_notification(approval, chat, owner, requester, created?) do
      {:ok, approval}
    else
      nil -> {:error, :requester_not_found}
      error -> error
    end
  end

  def approve(id, token, owner_user_id) do
    with {:ok, approval} <- claim(id, token, owner_user_id, "executing"),
         {:ok, result} <- replay(approval),
         {:ok, approval} <- complete(approval, result) do
      {:ok, approval, result}
    else
      {:error, reason} = error ->
        mark_failed(id, reason)
        error
    end
  end

  def reject(id, token, owner_user_id) do
    claim(id, token, owner_user_id, "rejected")
  end

  def get_for_replay(id) do
    Repo.one(
      from approval in ManagementApproval,
        where: approval.id == ^id and approval.status == "executing"
    )
  end

  def get(id), do: Repo.get(ManagementApproval, id)

  def replay_authorization(id) do
    Phoenix.Token.sign(PolicrMiniWeb.Endpoint, "management-approval", id)
  end

  def verify_replay_authorization(token) do
    with {:ok, id} <-
           Phoenix.Token.verify(PolicrMiniWeb.Endpoint, "management-approval", token,
             max_age: 120
           ),
         %ManagementApproval{} = approval <- get_for_replay(id),
         %User{} = user <- Accounts.get_user(approval.requester_user_id) do
      {:ok, approval, user}
    else
      _ -> {:error, :invalid_approval_authorization}
    end
  end

  def pending_payload(approval) do
    %{
      success: false,
      approval_pending: true,
      approval_id: approval.id,
      message: "操作已提交群主审批，请在 WuFengBot 私聊中确认后执行。"
    }
  end

  def notification_result_text(%ManagementApproval{} = approval, outcome) do
    status =
      case outcome do
        :approved -> "✅ 已同意并执行"
        :rejected -> "❌ 已拒绝，未执行"
        {:failed, reason} -> "⚠️ 已同意，但执行失败：#{format_error(reason)}"
      end

    notification_text(approval, status)
  end

  defp request_attrs(conn, chat, owner, requester) do
    params = body_params(conn)
    action_key = action_key(conn)
    summary = summarize(action_key, conn.params, params)

    base_attrs(
      chat.id,
      owner.id,
      requester.id,
      conn.method,
      conn.request_path,
      params,
      action_key,
      summary
    )
  end

  defp base_attrs(chat_id, owner_id, requester_id, method, path, params, action_key, summary) do
    fingerprint_source = JSON.encode!(%{method: method, path: path, params: params})

    %{
      chat_id: chat_id,
      owner_user_id: owner_id,
      requester_user_id: requester_id,
      request_method: String.upcase(to_string(method)),
      request_path: path,
      request_params: params,
      action_key: action_key,
      summary: summary,
      request_fingerprint:
        :crypto.hash(:sha256, fingerprint_source) |> Base.encode16(case: :lower),
      callback_token: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
      status: "pending"
    }
  end

  defp insert_or_get_pending(attrs) do
    case %ManagementApproval{} |> ManagementApproval.changeset(attrs) |> Repo.insert() do
      {:ok, approval} ->
        {:ok, approval, true}

      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :request_fingerprint) do
          approval =
            Repo.one(
              from approval in ManagementApproval,
                where:
                  approval.chat_id == ^attrs.chat_id and
                    approval.requester_user_id == ^attrs.requester_user_id and
                    approval.request_fingerprint == ^attrs.request_fingerprint and
                    approval.status == "pending",
                limit: 1
            )

          if approval, do: {:ok, approval, false}, else: {:error, :approval_conflict}
        else
          {:error, :approval_invalid}
        end
    end
  end

  defp ensure_notification(approval, _chat, _owner, _requester, false), do: {:ok, approval}

  defp ensure_notification(approval, chat, owner, requester, true) do
    markup = %InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %InlineKeyboardButton{
            text: "✅ 同意并执行",
            callback_data: "approval:v1:a:#{approval.id}:#{approval.callback_token}"
          },
          %InlineKeyboardButton{
            text: "❌ 拒绝",
            callback_data: "approval:v1:r:#{approval.id}:#{approval.callback_token}"
          }
        ]
      ]
    }

    text =
      approval
      |> Map.put(:summary, approval.summary)
      |> notification_text("⏳ 等待群主确认", chat, requester)

    case Telegex.send_message(owner.id, text, parse_mode: "HTML", reply_markup: markup) do
      {:ok, %{message_id: message_id}} ->
        approval
        |> ManagementApproval.changeset(%{notification_message_id: message_id})
        |> Repo.update()

      {:error, error} ->
        approval
        |> ManagementApproval.changeset(%{
          status: "failed",
          last_error: format_error(error)
        })
        |> Repo.update()

        {:error, :owner_private_chat_unavailable}
    end
  end

  defp notification_text(approval, status, chat \\ nil, requester \\ nil) do
    chat = chat || Repo.get(Chat, approval.chat_id)
    requester = requester || Accounts.get_user(approval.requester_user_id)

    MessageTemplates.render(
      approval.chat_id,
      :management_approval_private,
      %{
        chat_title: html((chat && chat.title) || "群组 #{approval.chat_id}"),
        requester: html(full_name(requester)),
        requester_id: approval.requester_user_id,
        summary: html(approval.summary),
        status: html(status)
      },
      parse_mode: "HTML"
    )
  end

  defp claim(id, token, owner_user_id, next_status) do
    Repo.transaction(fn ->
      approval =
        Repo.one(
          from approval in ManagementApproval,
            where: approval.id == ^id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(approval) ->
          Repo.rollback(:not_found)

        approval.callback_token != token ->
          Repo.rollback(:invalid_token)

        approval.owner_user_id != owner_user_id ->
          Repo.rollback(:not_owner)

        approval.status != "pending" ->
          Repo.rollback({:already_decided, approval.status})

        true ->
          attrs = %{
            status: next_status,
            decided_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }

          Repo.update!(ManagementApproval.changeset(approval, attrs))
      end
    end)
  end

  defp replay(approval) do
    token = replay_authorization(approval.id)
    body = JSON.encode!(approval.request_params || %{})

    conn =
      Plug.Test.conn(approval.request_method, approval.request_path, body)
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "approval #{token}")

    try do
      response = PolicrMiniWeb.Endpoint.call(conn, PolicrMiniWeb.Endpoint.init([]))
      result = %{status: response.status, body: response.resp_body || ""}

      if response.status in 200..299 do
        {:ok, result}
      else
        {:error, {:http_error, response.status, truncate(response.resp_body || "")}}
      end
    rescue
      error -> {:error, error}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp complete(approval, result) do
    approval
    |> ManagementApproval.changeset(%{
      status: "approved",
      response_status: result.status,
      response_body: truncate(result.body),
      executed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  defp mark_failed(id, reason) do
    case Repo.get(ManagementApproval, id) do
      %ManagementApproval{status: "executing"} = approval ->
        approval
        |> ManagementApproval.changeset(%{status: "failed", last_error: format_error(reason)})
        |> Repo.update()

      _ ->
        :ok
    end
  end

  defp resolve_chat_id(conn) do
    controller = conn.private.phoenix_controller
    action = conn.private.phoenix_action
    params = conn.params

    cond do
      controller == PolicrMiniWeb.ConsoleV2.API.SchemeController ->
        with {:ok, scheme} <- Chats.load_scheme(params["id"]), do: {:ok, scheme.chat_id}

      controller == PolicrMiniWeb.ConsoleV2.API.VerificationController ->
        case conn.assigns[:verification] do
          %{chat_id: chat_id} -> {:ok, chat_id}
          _ -> {:error, :chat_not_found}
        end

      controller == PolicrMiniWeb.ConsoleV2.API.CustomController and action == :add ->
        parse_chat_id(params["chat_id"])

      controller == PolicrMiniWeb.ConsoleV2.API.CustomController ->
        with {:ok, custom} <- Chats.load_custom(params["id"]), do: {:ok, custom.chat_id}

      params["chat_id"] ->
        parse_chat_id(params["chat_id"])

      params["id"] ->
        parse_chat_id(params["id"])

      true ->
        {:error, :chat_not_found}
    end
  end

  defp requester(%{assigns: %{user: %User{} = user}}), do: {:ok, user}
  defp requester(_conn), do: {:error, :requester_not_found}

  defp find_owner(chat_id) do
    owner =
      Repo.one(
        from permission in Permission,
          join: user in User,
          on: user.id == permission.user_id,
          where: permission.chat_id == ^chat_id and permission.tg_is_owner == true,
          order_by: [desc: permission.updated_at],
          select: user,
          limit: 1
      )

    case owner do
      nil ->
        {:error, :owner_not_found}

      owner ->
        case Telegex.get_chat_member(chat_id, owner.id) do
          {:ok, %ChatMemberOwner{}} -> {:ok, owner}
          {:ok, _member} -> {:error, :owner_not_found}
          {:error, _reason} -> {:error, :owner_lookup_failed}
        end
    end
  end

  defp body_params(%{body_params: %Plug.Conn.Unfetched{}}), do: %{}
  defp body_params(%{body_params: params}) when is_map(params), do: params
  defp body_params(_conn), do: %{}

  defp action_key(conn) do
    controller = conn.private.phoenix_controller |> Module.split() |> List.last()
    "#{controller}.#{conn.private.phoenix_action}"
  end

  defp summarize(action_key, route_params, body_params) do
    label =
      Map.get(
        %{
          "LotteryController.create" => "创建并发布抽奖",
          "LotteryController.draw" => "立即开奖",
          "LotteryController.cancel" => "取消抽奖",
          "MemberController.sync" => "同步完整群成员名单",
          "MemberController.kick" => "移出成员并加入永久黑名单",
          "MemberController.unblock" => "解除成员黑名单",
          "ChatController.takeover" => "修改入群验证接管状态",
          "ChatController.copy_settings" => "复制另一个群组的管理设置",
          "ChatController.leave" => "让 WuFengBot 退出群组",
          "SchemeController.update" => "修改入群验证方案",
          "VerificationController.kill" => "处理验证记录成员",
          "CustomController.add" => "新增自定义验证题",
          "CustomController.update" => "修改自定义验证题",
          "CustomController.delete" => "删除自定义验证题",
          "PermissionController.update" => "修改管理员权限",
          "AutomationController.update" => "修改消息与自动化设置",
          "AutomationController.add_forbidden_word" => "新增违禁词规则",
          "AutomationController.delete_forbidden_word" => "删除违禁词规则",
          "AutomationController.add_keyword_reply" => "新增关键词自动回复",
          "AutomationController.update_keyword_reply" => "修改关键词自动回复",
          "AutomationController.delete_keyword_reply" => "删除关键词自动回复",
          "AutomationController.add_forbidden_whitelist" => "新增违禁词白名单",
          "AutomationController.delete_forbidden_whitelist" => "删除违禁词白名单",
          "AutomationController.add_schedule" => "新增定时群消息",
          "AutomationController.update_schedule" => "修改定时群消息",
          "AutomationController.test_schedule" => "试发定时群消息",
          "AutomationController.delete_schedule" => "删除定时群消息"
        },
        action_key,
        "执行群管理操作"
      )

    details = detail_values(action_key, route_params, body_params)
    if details == "", do: label, else: "#{label}｜#{details}"
  end

  defp detail_values(action_key, route, body) do
    keys =
      case action_key do
        "LotteryController.create" -> ~w(title prize winner_count entry_keyword auto_delete_entry_messages entry_message_delete_after_seconds end_at)
        "MemberController.kick" -> ~w(reason)
        "ChatController.copy_settings" -> ~w(source_chat_id)
        "PermissionController.update" -> ~w(readable writable configurable)
        "AutomationController.add_forbidden_word" -> ~w(word action)
        "AutomationController.add_keyword_reply" -> ~w(keywords match_mode response_text)
        "AutomationController.update_keyword_reply" -> ~w(keywords match_mode response_text)
        "AutomationController.add_forbidden_whitelist" -> ~w(word)
        "AutomationController.add_schedule" -> ~w(title next_run_at)
        "AutomationController.update_schedule" -> ~w(title next_run_at)
        "VerificationController.kill" -> ~w(action)
        "CustomController.add" -> ~w(title)
        "CustomController.update" -> ~w(title)
        _ -> []
      end

    body_details =
      keys
      |> Enum.flat_map(fn key ->
        case Map.fetch(body, key) do
          {:ok, value} when value not in [nil, ""] -> ["#{key}=#{short(value)}"]
          _ -> []
        end
      end)

    route_details =
      ~w(user_id lottery_id schedule_id word_id rule_id reply_id)
      |> Enum.flat_map(fn key ->
        case Map.fetch(route, key) do
          {:ok, value} -> ["#{key}=#{short(value)}"]
          _ -> []
        end
      end)

    Enum.join(route_details ++ body_details, "，")
  end

  defp parse_chat_id(value) when is_integer(value), do: {:ok, value}

  defp parse_chat_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :chat_not_found}
    end
  end

  defp parse_chat_id(_value), do: {:error, :chat_not_found}

  defp full_name(nil), do: "未知用户"

  defp full_name(user) do
    [user.first_name, user.last_name]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> user.username || "用户 #{user.id}"
      value -> value
    end
  end

  defp html(value), do: value |> to_string() |> Telegex.Tools.safe_html()
  defp short(value) when is_list(value), do: value |> Enum.join(" / ") |> String.slice(0, 80)
  defp short(value), do: value |> to_string() |> String.slice(0, 80)
  defp truncate(value), do: value |> to_string() |> String.slice(0, @max_response_bytes)

  defp format_error({:http_error, status, body}), do: "HTTP #{status}: #{body}"
  defp format_error(%Telegex.Error{description: description}), do: description
  defp format_error(reason), do: inspect(reason, limit: 8, printable_limit: 500)
end
