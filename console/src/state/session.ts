import { createSignal } from "solid-js";

export type ConsoleSessionIssue = "expired" | "unauthorized" | "connection";

const [issue, setIssue] = createSignal<ConsoleSessionIssue | null>(null);

export const consoleSession = { issue };

export function blockConsoleSession(nextIssue: ConsoleSessionIssue) {
  setIssue(nextIssue);
}

export function clearConsoleSessionIssue() {
  setIssue(null);
}
