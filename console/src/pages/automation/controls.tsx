import { Icon } from "@iconify-icon/solid";
import { JSX } from "solid-js";

export const inputClass = "panel-input";
export const MAX_DELETE_SECONDS = 172_740;

export const SettingCard = (props: { icon: string; title: string; description: string; children: JSX.Element }) => (
  <section class="panel-card overflow-hidden">
    <div class="panel-card-header"><div><h2 class="panel-section-title"><Icon icon={props.icon} class="text-xl text-tea-600" />{props.title}</h2><p class="panel-muted mt-1">{props.description}</p></div></div>
    <div class="flex flex-col gap-3 p-5">{props.children}</div>
  </section>
);

export const Toggle = (props: { label: string; checked: boolean; onChange: (value: boolean) => void }) => (
  <label class="flex cursor-pointer items-center gap-3 text-sm font-semibold text-ink"><input class="h-5 w-5 accent-tea-600" type="checkbox" checked={props.checked} onChange={(event) => props.onChange(event.currentTarget.checked)} />{props.label}</label>
);

export const NumberField = (props: { label: string; value: number; onInput: (value: number) => void; hint?: string; max?: number; min?: number }) => (
  <label class="panel-muted">{props.label}<input class={inputClass + " mt-1"} type="number" min={props.min ?? 0} max={props.max ?? MAX_DELETE_SECONDS} value={props.value} onInput={(event) => props.onInput(toSeconds(Number(event.currentTarget.value), props.min ?? 0, props.max ?? MAX_DELETE_SECONDS))} />{props.hint && <small class="mt-1 block text-xs text-emerald-950/45">{props.hint}</small>}</label>
);

export function toSeconds(value: number, min = 0, max = MAX_DELETE_SECONDS) { return Math.max(min, Math.min(max, Number.isFinite(value) ? Math.floor(value) : min)); }
export function localDateTime(date: Date) { const pad = (value: number) => String(value).padStart(2, "0"); return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`; }
