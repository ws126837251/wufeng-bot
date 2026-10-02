import { render } from "solid-js/web";
import "./main.css";
import { QueryClient, QueryClientProvider } from "@tanstack/solid-query";
import App from "./App";

const client = new QueryClient({
  defaultOptions: {
    queries: {
      // 群组来回切换时直接复用刚读取的数据，避免每次都重新加载整页。
      staleTime: 60_000,
      gcTime: 10 * 60_000,
      refetchOnWindowFocus: false, // 禁止在窗口重新聚焦时重新获取数据
    },
  },
});

render(
  () => (
    <QueryClientProvider client={client}>
      <App />
    </QueryClientProvider>
  ),
  document.getElementById("app")!,
);
