import { Icon } from "@iconify-icon/solid";
import { JSX } from "solid-js";

export default (props: { title: string; icon: string; children: JSX.Element }) => {
  return (
    <div class="panel-card overflow-hidden">
      <h2 class="flex items-center gap-2 border-b border-emerald-950/8 bg-tea-50 px-4 py-3 text-base font-semibold text-ink">
        <Icon inline icon={props.icon} class="w-[1.25rem] text-[1.25rem] text-tea-600" />
        {props.title}
      </h2>
      <div class="flex flex-col gap-[1rem] px-4 py-4">
        {props.children}
      </div>
    </div>
  );
};
