import { createStore } from "solid-js/store";

type State = {
  currentPage: Page;
  currentChatId: number | null;
  currentChatTitle: string | null;
  currentChatCanConfigure: boolean;
  currentChatCanOperate: boolean;
  currentChatAccessRole: ServerData.Chat["accessRole"] | null;
  emptyChatList: boolean | null;
  drawerIsOpen: boolean;
};

const DEFAULT_PAGE: Page = "stats";

const [store, setStore] = createStore<State>({
  currentPage: DEFAULT_PAGE,
  drawerIsOpen: false,
  currentChatId: null,
  currentChatTitle: null,
  currentChatCanConfigure: false,
  currentChatCanOperate: false,
  currentChatAccessRole: null,
  emptyChatList: null,
});

export function setCurrentPage(page: Page) {
  setStore("currentPage", page);
}

export function setCurrentChat(chat: ServerData.Chat) {
  setStore("currentChatId", chat.id);
  setStore("currentChatTitle", chat.title);
  setStore("currentChatCanConfigure", chat.canConfigure);
  setStore("currentChatCanOperate", chat.canOperate);
  setStore("currentChatAccessRole", chat.accessRole);
  setStore("emptyChatList", false);
}

export function toggleDrawer() {
  setStore("drawerIsOpen", !store.drawerIsOpen);
}

export function closeDrawer() {
  setStore("drawerIsOpen", false);
}

export function setEmptyChatList(empty: boolean) {
  setStore("emptyChatList", empty);
}

export default store;
