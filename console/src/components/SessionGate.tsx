import { Icon } from "@iconify-icon/solid";
import { Show } from "solid-js";
import { clearConsoleSessionIssue, consoleSession } from "../state/session";

export default () => {
  const issueText = () => consoleSession.issue() === "connection"
    ? "暂时无法连接 WuFengBot 管理服务。请检查网络后重试。"
    : "本次管理授权已失效，或当前页面不是从 Telegram Mini App 打开的。";

  return (
    <Show when={consoleSession.issue()}>
      <main class="fixed inset-0 z-[100] grid place-items-center bg-[#edf5ee] p-5 text-ink">
        <section class="w-full max-w-md rounded-[2rem] border border-emerald-950/10 bg-white p-6 text-center shadow-[0_24px_72px_rgba(23,61,49,0.16)] sm:p-8">
          <div class="mx-auto grid h-16 w-16 place-items-center rounded-3xl bg-tea-100 text-tea-700">
            <Icon icon="solar:lock-keyhole-minimalistic-bold-duotone" class="text-3xl" />
          </div>
          <h1 class="mt-5 text-2xl font-black">需要重新授权</h1>
          <p class="mt-3 text-sm leading-6 text-emerald-950/60">{issueText()}</p>
          <div class="mt-6 grid gap-3 sm:grid-cols-2">
            <a
              href="https://t.me/wufengde_bot?start=panel"
              target="_blank"
              rel="noreferrer"
              class="rounded-2xl bg-tea-600 px-4 py-3 text-sm font-bold text-white transition hover:bg-tea-700"
            >
              打开 WuFengBot
            </a>
            <button
              type="button"
              onClick={() => {
                clearConsoleSessionIssue();
                window.location.reload();
              }}
              class="rounded-2xl border border-emerald-950/12 bg-white px-4 py-3 text-sm font-bold text-emerald-950/65 transition hover:border-tea-500/35 hover:text-tea-700"
            >
              重新检测
            </button>
          </div>
          <p class="mt-5 text-xs leading-5 text-emerald-950/42">正常使用请从机器人私聊或群内的“完整面板”进入；失效后无需猜测原因。</p>
        </section>
      </main>
    </Show>
  );
};
