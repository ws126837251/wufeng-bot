import { JSX } from "solid-js";
import FieldRoot from "./FieldRoot";

export default (
  props: {
    label: string;
    placeholder: string;
    type?: JSX.InputHTMLAttributes<HTMLInputElement>["type"];
    min?: number;
    max?: number;
    step?: number;
    value?: string | number;
    onInput?: (value: string) => void;
  },
) => {
  return (
    <FieldRoot label={props.label}>
      <input
        placeholder={props.placeholder}
        type={props.type || "text"}
        min={props.min}
        max={props.max}
        step={props.step}
        class="w-full h-[2.5rem] px-[1rem] input-edge"
        value={props.value}
        onInput={(e) => props.onInput?.(e.currentTarget.value)}
      />
    </FieldRoot>
  );
};
