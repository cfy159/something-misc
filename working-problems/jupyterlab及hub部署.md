# 服务器JupyterLab部署

1. 制作镜像

```shell
docker pull ubuntu:22.04
docker run -itd --name jupyterlab ubuntu:22.04
docker exec -it jupyterlab bash
```

2. 配置环境

进入docker容器中后

```shell
jupyter lab --generate-config

vim /home/sxyd/.jupyter/jupyter_lab_config.py
c.NotebookApp.ip = '0.0.0.0'  
c.NotebookApp.open_browser = False  
c.NotebookApp.port = 8899  
c.MappingKernelManager.root_dir = '/home/sxyd' #需保证此目录存在  
c.NotebookApp.allow_remote_access = True
# 禁用 token
c.ServerApp.token = ''
# 禁用密码
c.ServerApp.password = ''
# 加载.bashrc配置文件，jupyterlab终端默认不加载任何配置文件
c.ServerApp.terminado_settings = {'shell_command': ['/bin/bash', '-i']}
```

3. 启动jupyterlab当做服务

   **启动jupyterlab服务**

   如果是docker上的话，就无法进行这步

```shell
vim /etc/systemd/system/jupyterlab.service
```

```shell
[Unit]
Description=JupyterLab Service

[Service]
Type=simple
PIDFile=/run/jupyter.pid
ExecStart=/home/sxyd/miniconda3/envs/jupyterlab/bin/jupyter lab --config=/.jupyter/jupyter_lab_config.py
User=sxyd
Group=sxyd
WorkingDirectory=/home/sxyd/
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```



```shell
# Reload systemd manager configuration 
systemctl daemon-reload
# Start the JupyterLab service immediately 
systemctl start jupyterlab 
# Enable the service to start automatically at boot 
systemctl enable jupyterlab 
# Check the service status (optional) 
systemctl status jupyterlab
```

docker中

```shell
# 容器内部启动
nohup jupyter lab --ip=0.0.0.0 --port=8888 --allow-root > jupyter.log 2>&1 &

# 使用docker启动
docker run -d \
  -p 8888:8888 \
  --name my-jupyter \
  your-image-name \
  jupyter lab --ip=0.0.0.0 --port=8888 --allow-root
```

或者做成自启动的镜像

`dockerfile`

```dockerfile
FROM your-base-image

# 你已经装过的话可以省略
# RUN apt update && apt install -y python3-pip
# RUN pip install jupyterlab

# 容器启动时自动执行
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--allow-root"]
```

然后

```shell
docker build -t my-jupyter-image .
docker run -d -p 8888:8888 my-jupyter-image
```

4. 使用中文

```shell
pip install jupyterlab-language-pack-zh-CN
```

# 部署jupyterhub

## 部署流程

1. 拉取镜像

```shell
docker pull jupyterhub/jupyterhub:5.4.4
```

2. 启动镜像

```shell
docker run -d -p 8000:8000 --name jupyterhub jupyterhub/jupyterhub:5.4.4 jupyterhub
```

3. 进入容器

```shell
docker exec -it jupyterhub bash
```

4. 生成`jupyterhub`配置文件

```shell
jupyterhub --generate-config
```

5. 依赖更新

```shell
apt-get update && apt install vim -y
# 有需要可以安装中文库，根据自己需求进行处理，本教程不对此步骤做详细说明
pip install jupyterlab-language-pack-zh-CN -i https://mirrors.aliyun.com/pypi/simple
# 更新组件库
pip install jupyterhub --upgrade -i https://mirrors.aliyun.com/pypi/simple
pip install notebook --upgrade -i https://mirrors.aliyun.com/pypi/simple
```

6. 创建用户

```shell
adduser jupyterhub
```

7. 修改配置文件

```shell
cd /srv/jupyterhub && vim jupyterhub_config.py
```

添加：

```python
c.Authenticator.allow_all = True
c.Authenticator.allow_existing_users = True
c.Authenticator.admin_users = {'jupyterhub'}  # 管理员用户
c.DummyAuthenticator.password = "jupyterhub"  # 初始密码设置
c.JupyterHub.admin_access = True
c.LocalAuthenticator.create_system_users=True
c.Spawner.notebook_dir = '~'
c.Spawner.default_url = '/lab'
c.Spawner.args = ['--allow-root'] 
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'command': ['python3', '-m', 'jupyterhub_idle_culler', '--timeout=3600'],
        'admin':True
    }
]
```

部署完毕后访问：http://[ip]:8000

## 无密码自动登录

为了实现“所有用户都以固定默认用户登录、完全隐藏登录表单、禁止手动输入账号密码”，需要将 JupyterHub 的认证机制改为始终返回同一个用户名，并绕过登录页面。这可以通过编写一个自定义认证器（Authenticator）来实现，并在配置文件中指定。

下面是一个修改后的配置文件，它定义了一个 `FixedUserAuthenticator` 类，该类继承自 `LocalAuthenticator`，并重写了 `get_authenticated_user` 方法，使其直接返回固定用户名。这样，任何访问 JupyterHub 的请求都会自动以该用户身份登录，不会再显示登录表单。

`jupyterhub_config.py`

```python
# 导入所需模块
from jupyterhub.auth import LocalAuthenticator
from traitlets import Unicode

# 自定义认证器：始终返回固定用户
class FixedUserAuthenticator(LocalAuthenticator):
    fixed_username = Unicode('jupyterhub', config=True, help="固定用户名")

    async def get_authenticated_user(self, handler, data):
        # 直接返回固定用户，不进行任何认证
        return {'name': self.fixed_username}

# ===== 以下为原配置，已根据需求调整 =====

# 使用自定义认证器
c.JupyterHub.authenticator_class = FixedUserAuthenticator
c.FixedUserAuthenticator.fixed_username = 'jupyterhub'  # 固定用户名，可修改

# 允许所有用户（由于固定用户，此设置影响不大，但保留）
c.Authenticator.allow_all = True
c.Authenticator.allow_existing_users = True

# 管理员用户（固定用户默认为管理员）
c.Authenticator.admin_users = {'jupyterhub'}
c.JupyterHub.admin_access = True

# 自动创建系统用户（如果系统不存在固定用户，则创建）
c.LocalAuthenticator.create_system_users = True

# Spawner 配置
c.Spawner.notebook_dir = '~'       # 工作目录为用户家目录
c.Spawner.default_url = '/lab'     # 默认打开 Lab 界面
c.Spawner.args = ['--allow-root']  # 允许以 root 运行（仅在必要时使用）

# 空闲服务清理器
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'command': ['python3', '-m', 'jupyterhub_idle_culler', '--timeout=3600'],
        'admin': True
    }
]
```

