# 安装ZeroClaw

```shell
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash
```

## 设置为后台服务

```shell
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

日志默认设置为`systemd`日志

```shell
journalctl --user -u zeroclaw -f
```

## 卸载

删除服务

```shell
zeroclaw service stop
zeroclaw service uninstall
```

删除二进制

```shell
# cargo install / bootstrap
rm ~/.cargo/bin/zeroclaw

cargo uninstall zeroclaw
```

删除配置文件

```shell
rm -rf ~/.zeroclaw ~/.config/zeroclaw
```


