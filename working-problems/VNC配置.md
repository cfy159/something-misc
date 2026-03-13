# 1.安装VNC服务器

```shell
sudo apt install -y tightvncserver
```

# 2.初始化VNC密码

安装完成后，先初始化 VNC 登录密码，该密码用于后续客户端连接验证

```shell
tightvncserver
```

1. 首先设置 VNC 登录密码（密码长度 6-8 位，输入时不显示明文）：`You will require a password to access your desktops.`
2. 再次输入密码确认。
3. 随后提示是否设置「查看密码」（仅能查看桌面，无法操作，一般无需设置，输入 `n` 回车即可）：`Would you like to enter a view-only password (y/n)?`

# 3.配置VNC

## 3.1 停止当前会话

```shell
# 停止端口 :1 对应的 VNC 会话（若后续启动其他端口，替换为对应数字即可）
tightvncserver -kill :1
```

## 3.2 编辑xstartup

```shell
vim ~/.vnc/xstartup
# 默认配置就行
```

## 3.3启动VNC服务

```shell
chmod +x ~/.vnc/xstartup

# 启动 :1 会话，指定分辨率 1920x1080，深度 24（色彩质量）
tightvncserver :1 -geometry 1920x1080 -depth 24
# vnc端口号5900 + 回话号： 5901
```

# 4.配置开机自启动

## 4.1修改rc.local文件

在exit 0之前添加

```shell
# 延迟 15 秒，等待桌面环境就绪
sleep 15
# 以 pi 用户身份启动 VNC 服务（指定家目录，确保加载配置）
su - pi -c "/usr/bin/tightvncserver :1 -geometry 1920x1080 -depth 24"
```

修改完成后

```shell
sudo reboot
```

预备方案：

```shell
# 修改~/.bashrc
# 检查 VNC :1 会话是否运行，未运行则启动
if ! ps -aux | grep -q "[t]ightvncserver :1"; then
    /usr/bin/tightvncserver :1 -geometry 1920x1080 -depth 24
fi
```



