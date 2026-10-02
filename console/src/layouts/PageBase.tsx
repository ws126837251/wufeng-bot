import { destructure } from "@solid-primitives/destructure";
import { JSX, Match, Switch } from "solid-js";
import { globalState } from "../state";

export default (props: { children: JSX.Element }) => {
  const { emptyChatList } = destructure(globalState);

  return (
    <main class="min-h-screen overflow-y-auto bg-[#f5f7f4] px-edge pb-main-bottom pt-main-top text-foreground lg:pl-[19rem] lg:pr-8">
      <Switch>
        <Match when={emptyChatList() === true}>
          <div class="panel-card mx-auto max-w-xl p-8 text-center">
            <p class="panel-page-title text-xl">暂无可管理群组</p>
            <p class="panel-muted mt-2">请先把机器人加入群组，并授予必要的管理员权限。</p>
          </div>
        </Match>
        <Match when={true}>
          {props.children}
        </Match>
      </Switch>
    </main>
  );
};
