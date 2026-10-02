import { Toast, Toaster } from "@ark-ui/solid";
import { MetaProvider, Title } from "@solidjs/meta";
import { Route, Router, RouteSectionProps } from "@solidjs/router";
import { DesktopNavigation, Drawer, NavigationBar, Overlay, TitleBar } from "./layouts";
import { SessionGate } from "./components";
import { AutomationPage, ControlPage, CustomizePage, HistoriesPage, MembersPage, PermissionsPage, StatsPage } from "./pages";
import { metaState } from "./state";
import { toaster } from "./utils";

const Layout = (props: RouteSectionProps) => {
  return (
    <>
      <Drawer /> {/* 抽屉菜单 */}
      <Overlay /> {/* 遮罩层 */}
      <SessionGate />
      <TitleBar /> {/* 标题栏 */}
      <DesktopNavigation />
      {props.children} {/* 页面内容 */}
      <NavigationBar /> {/* 底部导航栏 */}
    </>
  );
};

export default () => {
  return (
    <MetaProvider>
      <Title>{metaState.pageTitle}</Title>
      <Router base="/console/v2" root={Layout}>
        <Route path={["/stats", "/", "/dashboard"]} component={StatsPage} />
        <Route path={["/control", "/security"]} component={ControlPage} />
        <Route path={["/customize", "/custom-verification"]} component={CustomizePage} />
        <Route path={["/automation", "/messages", "/lottery"]} component={AutomationPage} />
        <Route path={["/histories", "/logs"]} component={HistoriesPage} />
        <Route path="/members" component={MembersPage} />
        <Route path="/permissions" component={PermissionsPage} />
      </Router>
      <Toaster toaster={toaster}>
        {(toast) => (
          <Toast.Root>
            <Toast.Title>{toast().title}</Toast.Title>
            <Toast.Description>{toast().description}</Toast.Description>
          </Toast.Root>
        )}
      </Toaster>
    </MetaProvider>
  );
};
