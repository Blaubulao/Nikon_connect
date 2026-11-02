# Windows + iPhone：Nikon Connect 安装与续签指南

适用于使用 Windows 电脑、希望把 Nikon Connect 安装到自己 iPhone 上的用户。不需要 Mac，也不需要购买 Apple 开发者会员。

本指南根据 2026 年 11 月 2 日在 Windows 上打包、签名并安装到 iPhone 的过程整理。

- 本 fork：[Blaubulao/Nikon_connect](https://github.com/Blaubulao/Nikon_connect)。
- 原项目：[yyhhzzzzz/Nikon_connect](https://github.com/yyhhzzzzz/Nikon_connect)。
- 已有 `NikonConnect-unsigned.ipa` 文件：直接从“二、在 Windows 上安装到 iPhone”开始。
- 还没有 IPA 文件：先按“一、获取 IPA 安装包”生成。

## 一、获取 IPA 安装包

本 fork 已包含 [GitHub Actions 打包配置](.github/workflows/build-ios.yml)，打包在 GitHub 的 macOS 机器上完成，Windows 本机不用安装 Xcode。

1. 登录 GitHub，打开本 fork 的 [Build iPhone IPA 页面](https://github.com/Blaubulao/Nikon_connect/actions/workflows/build-ios.yml)。
2. 如果提示工作流未启用，先启用。
3. 点击 **Run workflow**，选择 `main` 分支，再点击运行。
4. 等待出现绿色对勾，确认整次运行成功。
5. 打开这次成功的运行，在页面下方 **Artifacts** 区域下载 **NikonConnect-unsigned-IPA**。
6. 解压下载的 ZIP，取出里面的 **`NikonConnect-unsigned.ipa`**。
7. 把 IPA 单独保存，后续安装、续签和换电脑都可以继续使用。

解压外层 ZIP 即可；保留里面的 `.ipa` 文件，不需要继续解压 IPA。

如果使用自己的另一个 fork，打开自己仓库里的同名工作流。修改源文件或工作流后，应重新点击 **Run workflow**，让新运行使用最新代码。

### 两种“7 天”要分清

| 项目 | 有效期及影响 |
| --- | --- |
| GitHub 上的构建产物下载 | 当前工作流保留 7 天，之后可能无法从该次运行下载；可以重新运行工作流生成。 |
| 免费 Apple 账号签名 | 通常有效 7 天，之后手机里的 App 需要续签才能继续打开。 |
| 已保存到电脑或网盘的未签名 IPA | 不会因为上述 7 天期限自动失效，可继续用于签名安装；更新 App 时再换成新版本 IPA。 |

## 二、在 Windows 上安装到 iPhone

### 1. 准备文件和软件

| 准备项 | 用途及说明 |
| --- | --- |
| Windows 电脑 | 本次使用 Windows 完成操作，建议使用 Windows 10/11。 |
| iPhone 和数据线 | 数据线需要支持传输数据，不能只有充电功能。 |
| Sideloadly | 从 [Sideloadly 官网](https://sideloadly.io/)下载 Windows 版并安装，用于签名和安装 IPA。 |
| iTunes | 从 [苹果官网下载 Windows 64 位版](https://www.apple.com/itunes/download/win64)，安装后用于识别和连接手机。 |
| `NikonConnect-unsigned.ipa` | 上一步生成或之前已经备份的安装包。 |
| 自己的 Apple 账号 | 免费账号即可，后续续签继续使用同一个账号。 |

**关于 iCloud：** Sideloadly 官网目前将苹果官网版 iTunes 和 iCloud 列为 Windows 依赖。本次实际安装没有单独下载安装 iCloud，也完成了签名和安装，因此已经能正常安装时不用再补装。换电脑时先准备 iTunes、Sideloadly 和 IPA；如果 Sideloadly 提示缺少 iCloud 或苹果验证组件，再按它的提示及[官网说明](https://sideloadly.io/)补装。需要补装时使用官网提供的苹果安装器，避免混用不同来源的苹果组件。

### 2. 让电脑识别手机

1. 用数据线连接 iPhone 和 Windows 电脑。
2. 解锁 iPhone。如果弹出 **信任此电脑**，选择 **信任**，并在手机上按提示输入锁屏密码。
3. 打开 iTunes，确认能看到手机图标。
4. 打开 Sideloadly，确认 **iDevice** 一栏显示自己的 iPhone。

能显示手机后，再继续安装 IPA。

### 3. 用 Sideloadly 安装

1. 将 **`NikonConnect-unsigned.ipa`** 拖到 Sideloadly 左上角的 IPA 图标上。
2. 确认 **iDevice** 选中的是自己的 iPhone。
3. 在 **Apple ID** 一栏填写自己的 Apple 账号。
4. 点击 **Start**。
5. 如果弹出账号密码或双重认证提示，直接在本机 Sideloadly 窗口里完成验证。
6. 等待底部显示 **Done**，再到 iPhone 桌面查看 **Nikon Connect**。

免费账号通常使用 Apple 账号的正常登录密码，不是 iPhone 锁屏密码，也不是“App 专用密码”。密码和验证码只在本机软件或苹果官网输入，不要上传到 GitHub、写入项目或贴到日志里。

## 三、在 iPhone 上允许打开 App

### 提示“不受信任的开发者”

这表示 App 已安装到手机，但尚未信任用于签名的开发者账号。

1. 关闭提示，打开 **设置 → 通用 → VPN 与设备管理**。
2. 在 **开发者 App** 下，点开刚才用于安装的 Apple 账号。
3. 点击 **信任**，并确认。如果系统要求允许并重新启动，按提示操作。
4. 回到桌面，重新打开 **Nikon Connect**。

### 提示需要“开发者模式”

1. 打开 **设置 → 隐私与安全性 → 开发者模式**。
2. 开启开发者模式，按提示重新启动手机。
3. 重启后确认开启，再打开 **Nikon Connect**。

首次进入 App 时，按实际提示允许本地网络访问、照片等权限。随后再按相机和 App 的连接指引尝试连接。原项目将尼康连接标为实验性功能，具体机型的连接和传图效果仍需实际验证。

## 四、7 天后过期，如何续签

免费 Apple 账号签名通常有效 7 天。过期后 App 一般仍在手机里，但无法正常打开，需要重新签名安装。

1. 用数据线把 iPhone 接到电脑，解锁并确认电脑能识别手机。
2. 打开 Sideloadly，再次选中之前保存的 **`NikonConnect-unsigned.ipa`**。
3. 使用与上次安装相同的 **Apple 账号**，沿用原安装设置。
4. 点击 **Start**，按提示验证，等待 **Done**。
5. 回到手机重新打开 App；如系统再次要求信任，按第三部分操作。

**直接覆盖安装，不要先删除手机上的 App。** 使用相同账号和应用标识覆盖安装通常可以保留原有设置和数据；重要数据仍应保留备份。续签不需要重新 fork 项目，也不需要每次都重新运行 GitHub 打包。

### 自动续签

Sideloadly 支持把 App 加入自动续签。安装时开启对应的自动刷新选项后，由 Sideloadly Daemon 后台程序尝试在临近到期时续签。

自动续签需要电脑开机、后台程序运行，并且能通过 USB 或已配置好的 Wi-Fi 连接发现手机。最直接的方式是连接数据线；如需无线续签，先按 [Sideloadly FAQ](https://sideloadly.io/faq) 配置 Wi-Fi 同步，并让电脑和手机连接同一个网络。电脑关机或长期无法连接手机时，仍可能过期。

## 五、以后换电脑，怎么办

换电脑之前，把 **`NikonConnect-unsigned.ipa`** 备份到网盘或 U 盘。无需携带整个源码项目。

新 Windows 电脑按以下顺序操作：

1. 安装 **Sideloadly** 和苹果官网版 **iTunes**。
2. 把备份的 **IPA 文件**复制到新电脑。
3. 如果 Sideloadly 提示缺少苹果验证组件，按第二部分的 iCloud 说明补齐。
4. 用数据线连接 iPhone，解锁并在手机上 **信任此电脑**。
5. 在 Sideloadly 中选择手机和 IPA，使用原来的 **同一个 Apple 账号**，沿用原安装设置。
6. 点击 **Start**，等待 **Done**。

手机上原有的 App 保留着，直接覆盖安装即可。新电脑不需要先安装 Git、下载源码或重新配置 GitHub 工作流。

## 六、常见问题

### `Login failed (-20970)` / `Your account information was entered incorrectly`

表示 Apple 账号验证未通过，仅凭该错误码不能确定一定是密码输错。

1. 用浏览器打开 [苹果账号官网](https://account.apple.com/)，确认同一个账号和密码能够正常登录。
2. 核对 Sideloadly 中填写的账号，重新输入正常登录密码；免费账号不要用锁屏密码或 App 专用密码替代。
3. 如果网页登录正常，但 Sideloadly 仍报错，按软件提示检查苹果验证组件和网络，并记录具体错误；不必因此重新打包 IPA。

### Sideloadly 看不到 iPhone

先解锁手机、连接支持传输数据的数据线，并在手机上信任电脑。再打开 iTunes 确认能识别手机；仍不识别时，检查苹果组件安装，或换 USB 接口、数据线后重试。

### 手机提示“不受信任的开发者”或“需要开发者模式”

按第三部分完成信任或开启开发者模式后，再打开 App。

### GitHub Actions 显示 `Process completed with exit code 65`

这是构建阶段失败的退出码，需要查看真正的编译错误。

在失败运行中查看 **Show compiler errors**，或下载 **NikonConnect-build-log**，寻找具体的 `error:` 信息。修复并保存文件后，再从最新 `main` 分支发起一次新的 **Run workflow**。

### GitHub 上的安装包下载过期了

如果本地已有 IPA，继续用保存的文件即可。如果没有备份，就按第一部分重新运行工作流并下载新的产物。

## 参考链接

- [本 fork 的打包工作流](https://github.com/Blaubulao/Nikon_connect/actions/workflows/build-ios.yml)
- [Sideloadly 官网与 Windows 下载](https://sideloadly.io/)
- [Sideloadly 官方 FAQ](https://sideloadly.io/faq)
- [苹果账号官网](https://account.apple.com/)
- [苹果官网 iTunes Windows 64 位安装器](https://www.apple.com/itunes/download/win64)
