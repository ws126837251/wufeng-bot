import { toaster } from "./toaster";

type ActionResponse = { success: boolean; message?: string; approvalPending?: boolean };

type ActionOptions = {
  success?: { title: string; description: string };
  failureTitle?: string;
  connectionTitle?: string;
};

export async function runConsoleAction<T extends ActionResponse>(
  request: () => Promise<T>,
  options: ActionOptions = {},
): Promise<T | undefined> {
  try {
    const response = await request();

    if (!response.success && !response.approvalPending) {
      toaster.error({
        title: options.failureTitle || "操作未执行",
        description: response.message || "服务器没有返回可用的失败原因，请稍后重试。",
        duration: 5_000,
      });
      return response;
    }

    if (response.success && options.success) {
      toaster.success({ ...options.success, duration: 3_500 });
    }

    return response;
  } catch (error) {
    toaster.error({
      title: options.connectionTitle || "连接失败",
      description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。",
      duration: 5_000,
    });
    return undefined;
  }
}
