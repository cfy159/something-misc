# UFW防火墙使用指南

## 查看状态

```shell
sudo ufw status
```

## 防火墙控制

```shell
# 开启
sudo ufw enable
# 关闭
sudo ufw disable
```

## 开放端口访问

```shell
sudo ufw allow <端口号>

# 允许某个IP访问访问8888端口
sudo ufw allow from 192.168.1.100 to any port 8888
# 允许整个局域网访问8888端口
sudo ufw allow from 192.168.0.0/16 to any port 8888
# 允许整个局域网访问所有端口
sudo ufw allow from 192.168.0.0/16
```

## 删除规则

```shell
# 删除一条规则
sudo ufw delete allow <端口号>

# 重置所有规则
sudo ufw reset
```

## systemd控制防火墙服务

### 停止服务

```shell
sudo systemctl stop ufw
```

### 禁止开机自启

```shell
sudo systemctl disable ufw
```

### 启动开机自启

```shell
sudo systemctl enable --now ufw
```


