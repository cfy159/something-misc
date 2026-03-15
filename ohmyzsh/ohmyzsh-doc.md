# zsh终端工具配置

## 安装

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## 主题

```shell
vim ~/.zshrc
# 修改
ZSH_THEME="darkblood"
```

## 补全工具

```shell
# 安装插件
cd ~/.oh-my-zsh/custom/plugins
git clone https://github.com/zsh-users/zsh-autosuggestions.git
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
git clone https://github.com/zsh-users/zsh-completions.git

# 修改配置
vim ~/.zshrc
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
```

**高亮颜色修改**

```shell
echo "ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=cyan'" >> ~/.zshrc
```
