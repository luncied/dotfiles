# dotfiles
Dotfiles config for zsh, p10k, neovim

## Install

```shell
git clone git@github.com:luncied/dotfiles.git ~/dotfiles
```
```


```shell
cd ~/dotfiles
chmod +x setup_dotfiles.sh
./setup_dotfiles.sh
```


  On windows we need to move the dir of nvim to `~\AppData\Local\nvim`. We create a symlink to that directory.

```powershell
New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\nvim" -Target "$HOME\.config\nvim"
```
```
```
