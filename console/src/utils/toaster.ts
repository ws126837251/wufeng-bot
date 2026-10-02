import { createToaster } from "@ark-ui/solid";

export const toaster = createToaster({
  placement: "top",
  duration: 4_000,
  overlap: true,
  gap: 16,
});
