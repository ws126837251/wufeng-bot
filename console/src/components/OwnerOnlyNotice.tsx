import { Icon } from "@iconify-icon/solid";

export default () => (
  <div class="flex items-start gap-3 rounded-2xl border border-amber-300/45 bg-amber-50 px-4 py-3 text-amber-950">
    <Icon icon="solar:lock-keyhole-minimalistic-bold-duotone" class="mt-0.5 shrink-0 text-xl text-amber-600" />
    <div class="text-sm leading-6">
      <p class="font-bold">当前账号没有配置修改权限</p>
      <p class="text-amber-900/70">群主可以在“权限管理”中为管理员开启配置权限。您仍可使用已授权的抽奖、开奖、状态检查和成员处理等执行功能。</p>
    </div>
  </div>
);
