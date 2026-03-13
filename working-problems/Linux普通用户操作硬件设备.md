

# Linux中普通用户操作硬件设备

​	我们这里以i2c设备为例，你可以直接修改/dev/i2c-*的文件权限，但是这种方式并不安全，我们这里使用udev对硬件设备权限进行管理。

## 1.确认设备和组的信息

1. 确保存在该设备文件；

```bash
ls /dev/i2c-*
```



2) 查询指定组信息；

下面两条命令都可以实现

```bash
getent group i2c
```

```bash
cat /etc/group | grep i2c
```

i2c组在安装i2c-tools的时候会默认创建一个i2c组，不需要再额外创建。



## 2.创建udev规则文件

```bash
sudo vim /etc/udev/rules.d/99-i2c.rules
# 规则文件命名规则： [优先级]-[描述].rules
# 数字越小，优先级越高
```

写入以下内容：

```bash
KERNEL=="i2c-[0-9]*", GROUPS="i2c", MODE="0660"
```

- KERNEL: 需要匹配的硬件设备文件
- GROUP：硬件设备所属的组
- MODE：设置文件权限为rw-rw----，允许组成员读写



## 3.将用户添加入i2c组

```bash
sudo usermod -aG i2c username
```



## 4.重新加载udev

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

重启系统

```bash
sudo reboot
```

## 5.验证配置

看权限是否更改，以及所属用户组是否与配置相同；

```bash
ls -l /dev/i2c-*
```

确认用户组，查看输出内容是否包含i2c；

```bash
groups username
```
