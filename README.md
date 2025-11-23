These are my personal dotfiles for my Arch Linux + Hyprland laptop setup. Before trying to learn AGS (Aylur's GTK Shell), I wanted to move everything onto Github before I fuck everything up.

### Setup:
OS (Operating System): Arch Linux
WM (Window Manager): Hyprland
Terminal: Kitty
Launcher: Fuzzel
Notification Daemon: Dunst
Key remapping: KMonad
Editor: Neovim
Internet Browser: Zen Browser
File Manager: Nemo, Ranger
IME (Input Method Editor): fcitx5

(Custom scripts using dunst replacing a information bar).

---
### installation
<!-- Clone the repository: -->
sudo pacman -S stow
git clone: ~/dotfiles
cd ~/dotfiles

<!-- Install Packages -->
stow *

#### Other Configurations

##### Fcitx5
Need to be re-installed through fcitx5 configuration tool
- fcitx5-mozc (Japanese)
- fcitx5-English (US)
- fcitx5-Norwegian (bokmål)

##### Installing pacman and yay packages
sudo pacman -S --needed - < pkglist.txt
yay -S --needed - < aurlist.txt

##### ly display manager
sudo systemctl enable ly.service
sudo systemctl start ly.service

##### systemd services for notification scripts
systemctl --user daemon-reload
systemctl --user enable batteryNotif5m.timer
systemctl --user enable batteryNotif1m.timer
systemctl --user start batteryNotif5m.timer
systemctl --user start batteryNotif1m.timer

##### Keys
<!-- SSH Keys -->
ssh-keygen -t ed25519 -C <Email>
ssh-add ~/.ssh/id_ed25519
