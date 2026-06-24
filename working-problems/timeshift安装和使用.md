# timeshift安装和使用

## 安装

```shell
sudo apt update
sudo apt install timeshift cron
```

### 确定分区

```shell
lsblk -f
```

```markdown
mmcblk2
│                                                                           
├─mmcblk2p1
│                                                                           
├─mmcblk2p2
│                                                                           
├─mmcblk2p3
│                                                                           
├─mmcblk2p4
│                                                                           
├─mmcblk2p5
│                                                                           
├─mmcblk2p6
│                                                                           
├─mmcblk2p7
│                                                                           
├─mmcblk2p8
│    ext4   1.0   rootfs
│                       cc367309-976a-47ef-bd45-350f4f6e5c81                
└─mmcblk2p9
     ext4   1.0   userdata
                        db63434c-f447-4fb6-bfc3-aa2e0725e305                
mmcblk2boot0

mmcblk2boot1
```

```shell
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
```

```markdown
NAME          SIZE FSTYPE LABEL    MOUNTPOINT
mmcblk2      58.2G                 
├─mmcblk2p1     4M                 
├─mmcblk2p2     4M                 
├─mmcblk2p3     4M                 
├─mmcblk2p4    16M                 
├─mmcblk2p5    40M                 
├─mmcblk2p6    32M                 
├─mmcblk2p7    32M                 
├─mmcblk2p8  21.8G ext4   rootfs   
└─mmcblk2p9  36.4G ext4   userdata 
mmcblk2boot0    4M                 
mmcblk2boot1    4M 
```



你担心得完全正确：如果快照放在 `/dev/mmcblk2p9`（也就是系统当前的 `/data` 分区），Timeshift 会把正在使用的数据一起备份，既浪费空间又可能造成递归备份或恢复时的不一致。

**理想的方案有两种：**

1. **使用外部存储**（U盘、移动硬盘或TF卡）—— **最安全、最简单，强烈推荐**
2. **在 eMMC 上重新划分一个新分区**—— 有风险，需要缩容现有分区，但确实可以做到

下面分别说明步骤。

---

## 方案一：使用外部存储（U盘/SD卡）

这是最稳妥的方式，不会动到现有系统分区，拔掉还能离线保存备份。

### 操作步骤

1. **插入 U 盘（或 TF 卡），查看设备名**
   
   ```bash
   lsblk
   ```
   
   你会看到类似 `sda`（U盘）或 `mmcblk1`（外部TF卡）。

2. **确认设备路径**（假设是 `/dev/sda1` 分区）
   
   ```bash
   sudo fdisk -l /dev/sda
   ```
   
   如果没有分区，可以新建一个，并格式化为 ext4：
   
   ```bash
   sudo parted /dev/sda mklabel msdos
   sudo parted /dev/sda mkpart primary ext4 0% 100%
   sudo mkfs.ext4 /dev/sda1
   ```

3. **创建挂载点并挂载**
   
   ```bash
   sudo mkdir -p /mnt/timeshift
   sudo mount /dev/sda1 /mnt/timeshift
   ```

4. **配置 Timeshift 使用该分区**
   第一次运行直接指定设备：
   
   ```bash
   sudo timeshift --create --snapshot-device /dev/sda1 --live
   ```
   
   或先生成配置文件：
   
   ```bash
   sudo timeshift --create --snapshot-device /dev/sda1
   ```
   
   之后 Timeshift 会记住这个设备，以后只需 `sudo timeshift --create` 即可。

> 💡 如果你希望插入 U 盘后自动挂载，可以把分区信息写入 `/etc/fstab`，但这不是必须的。

---

## 方案二：在 eMMC 上新建一个备份分区

如果你的 eMMC（`/dev/mmcblk2`）上还有未分配空间，可以直接创建新分区。如果没有，就需要从现有的 `p9`（data 分区）尾部“切”出一块空间，前提是 `p9` 的文件系统支持在线缩小（ext4 支持）。

**⚠️ 风险提示：任何分区调整都可能导致数据丢失，请务必先备份重要数据到外部存储。**

### 1. 查看现有分区布局

```bash
sudo parted /dev/mmcblk2 print free
```

观察最后是否有 “Free Space”。如果有一块几 GB 以上的空闲空间，直接跳到第 3 步创建分区。

### 2. 如果无空闲空间，缩容 p9 分区（示例）

假设你想从 p9 里分出 32GB 给备份分区。

- **卸载 p9**（这需要你的 `/data` 不是正在使用的挂载点，可能需要从 TF 卡启动一个临时系统，或者至少确认 `/data` 可以卸载）  
  
  ```bash
  sudo umount /dev/mmcblk2p9
  ```
  
  如果系统根 overlay 依赖 p9，你可能无法直接卸载。这种情况**强烈建议改用外部存储**，否则操作太复杂。

- **检查文件系统错误并缩小**
  
  ```bash
  sudo e2fsck -f /dev/mmcblk2p9
  sudo resize2fs /dev/mmcblk2p9  XXG   # 将文件系统缩小到指定大小，比如保留原大小的70%，留出空间
  ```

- **缩小分区本身**
  
  ```bash
  sudo parted /dev/mmcblk2
  (parted) resizepart 9  XXGB   # 结束位置设为文件系统缩小后的大小
  (parted) quit
  ```

- **创建新分区**（现在尾部应该有可用空间）
  
  ```bash
  sudo parted /dev/mmcblk2 mkpart primary ext4  XXGB 100%
  ```
  
  例如 `mkpart primary ext4 30GB 100%`。

### 3. 格式化新分区并挂载

```bash
sudo mkfs.ext4 /dev/mmcblk2p10   # 假设新分区是 p10
sudo mkdir -p /mnt/timeshift
sudo mount /dev/mmcblk2p10 /mnt/timeshift
```

### 4. 将分区信息写入 /etc/fstab（可选）

```bash
echo "/dev/mmcblk2p10 /mnt/timeshift ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

### 5. 配置 Timeshift 使用该分区

```bash
sudo timeshift --create --snapshot-device /dev/mmcblk2p10 --live
```

---

## 最终推荐

**直接用 U 盘或 TF 卡**，省去缩容、脱机等高风险操作，而且备份离线保存更安全。

操作完记得运行一次测试备份：

```bash
sudo timeshift --create --snapshot-device /dev/sda1 --live
```

如果还有任何报错（比如又遇到挂载问题），把输出发给我，我继续帮你排查。



Timeshift 的快照本质上是一个**文件级完整备份**（用 rsync + 硬链接生成），它不绑定特定机器的唯一标识，只要硬件/分区结构相同或你事后调整，就能跨机器恢复。

---

### 1. 快照在 U 盘上的目录结构

假设 U 盘挂载到 `/mnt/timeshift`，里面是这样的：

```
/mnt/timeshift/timeshift/
├── snapshots/
│   ├── 2026-06-24_12-00-00/
│   │   └── localhost/    ← 完整的系统文件树
│   └── ...
├── timeshift.json        ← 配置文件（记录备份类型、排除项等）
└── ...
```

新开发板上的 Timeshift 只要找到这个路径，就能列出并恢复快照。

---

### 2. 跨机器恢复的前提条件

| 条件            | 说明                                                                                    |
| ------------- | ------------------------------------------------------------------------------------- |
| **同一型号开发板**   | 如果是同款 NanoPC-T6，设备树、内核驱动完全一致，恢复后可直接启动。                                                |
| **分区布局一致**    | 根分区必须是同样的设备路径（如 `/dev/mmcblk2p8`），或恢复后手动修改 `fstab`。                                   |
| **需要从外部介质启动** | 不能在**正在运行的系统中**覆盖自己的根分区，必须用 Live 系统（另一个 U 盘/SD 卡）启动新板子，然后恢复。                          |
| **UUID 问题**   | 快照里的 `/etc/fstab` 会保留原板的磁盘 UUID，新板子 eMMC 的 UUID 不同会导致启动失败。恢复后要修改 fstab 或用分区标签代替 UUID。 |

---

### 3. 在新开发板上恢复的具体步骤

假设新板子也是 NanoPC-T6，且已从另一个 Live 系统（如 FriendlyCore 的 U 盘镜像）启动。

**① 插入快照 U 盘并挂载**

```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/sda1 /mnt/backup   # 假设 U 盘是 sda1
```

**② 挂载目标根分区**（新板子的 eMMC 根分区，通常是 `/dev/mmcblk2p8`）

```bash
sudo mkdir -p /mnt/root
sudo mount /dev/mmcblk2p8 /mnt/root
```

Timeshift 自动挂载的目标路径往往是 `/tmp/timeshift-xxxx/` 这种动态临时目录。恢复完成后，它一卸载，你就找不到那个挂载点了。  
而你想在**恢复后立刻修改 `/etc/fstab`**（修改根分区的 UUID 或设备路径），就需要目标分区在恢复后仍然处于挂载状态。  
手动挂到 `/mnt/root`，恢复完成后 `rsync` 会把文件全写进去，之后目标分区还老老实实挂在 `/mnt/root` 上，你就能直接 `sudo nano /mnt/root/etc/fstab` 去修改——这步是跨机恢复成败的关键。

**③ 用 timeshift 恢复**

```bash
sudo timeshift --restore --snapshot-device /dev/sda1
```

Timeshift 会交互式询问你要恢复到哪个分区，选择 `/dev/mmcblk2p8` 即可。  
如果遇到 Live CD 模式限制，加 `--live`：

```bash
sudo timeshift --restore --snapshot-device /dev/sda1 --live
```

**④ 修复 fstab 和启动配置**（重要！）
恢复后先不要重启，挂载根分区，修改 `/mnt/root/etc/fstab`：

```bash
sudo nano /mnt/root/etc/fstab
```

把原来根分区那一行的 UUID 改成新板子的真实 UUID（用 `blkid /dev/mmcblk2p8` 查看），或者直接用设备路径：

```
/dev/mmcblk2p8  /  ext4  defaults  0  1
```

如果快照里还有 `/data` 分区的挂载项，也做相应修改。

**⑤ 卸载并重启**

```bash
sudo umount /mnt/root /mnt/backup
sudo reboot
```

---

### 4. 如果是不同型号的板子

**强烈不推荐**，因为内核模块、设备树、GPU 驱动等都会不同，直接恢复大概率卡在启动阶段。  
但如果你只是要恢复一些**纯应用数据**（如 home 目录、配置文件），可以手动挂载快照目录，用 `rsync` 单拷贝需要的文件夹，不用 timeshift 整体恢复。

---

### 5. 最终结论

- **同型号 NanoPC-T6 板子之间**，用 U 盘/SD 卡做 Timeshift 快照 → 拔下来 → 在新板子上恢复，**完全可行**。
- 记住三件必做的事：**① 用 Live 系统启动新板子；② 恢复后修改 fstab；③ 确保 `/dev/mmcblk2p9` 等分区也存在（如果快照里有挂载 data 分区）**。

下次你实际操作时如果遇到任何报错，直接把输出发给我，我帮你一步步调。
