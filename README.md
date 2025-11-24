These are my personal dotfiles for my Arch Linux + Hyprland laptop setup. Before trying to learn AGS (Aylur's GTK Shell), I wanted to move everything onto Github before I fuck everything up.

### Setup:

| Ingredient                | Flavour      |
| ------------------------- | ------------ |
| OS (Operating System)     | Arch Linux   |
| WM (Windows Manager)      | Hyprland     |
| Terminal                  | Kitty        |
| Launcher                  | Fuzzel       |
| Notification Daemon       | Dunst        |
| Key Remapping             | KMonad       |
| Editor                    | Neovim       |
| Internet Browser          | Zen Browser  |
| File Managers             | Nemo, Ranger |
| IME (Input Method Editor) | fcitx5       |

(Custom scripts using dunst replacing a information bar).

---

### installation
> Clone the repository:
```bash
sudo pacman -S stow
git clone: ~/dotfiles
cd ~/dotfiles
```

> Install Packages
```bash
stow *
```

---

### Other Configurations

#### Fcitx5
Need to be re-installed through fcitx5 configuration tool
- fcitx5-mozc (Japanese)
- fcitx5-English (US)
- fcitx5-Norwegian (bokmål)

#### KMonad (Pain in the ass)
KMonad config file in `/home/$USER/.config/kmonad` as default.kbd

The input for default.kbd is found in `/dev/input`. There are two directories in here to look at. 
by-id/ directory is for devices connected externally.
by-path/ contains symlinks based on the physical path through the system bus (integrated devices).
Execute: `cat /proc/bus/input/devices` to identify the keyboard symlink.
Then write the kmonad.service file in `/etc/systemd/system/`. Ensure 'ExecStart' points to both the KMonad executable at `/usr/bin/kmonad` and the default.kbd file (in `/home/$USER/.config/kmonad`).
Start the service:
```bash
sudo systemctl enable --now kmonad.service
```

#### Installing pacman and yay packages
```bash
sudo pacman -S --needed - < pkglist.txt
yay -S --needed - < aurlist.txt
```

#### ly display manager
```bash
sudo systemctl enable ly.service
sudo systemctl start ly.service
```

#### systemd services for notification scripts
```bash
systemctl --user daemon-reload
systemctl --user enable batteryNotif5m.timer
systemctl --user enable batteryNotif1m.timer
systemctl --user start batteryNotif5m.timer
systemctl --user start batteryNotif1m.timer
```

#### Keys
> SSH Keys
```bash
ssh-keygen -t ed25519 -C <Email>
ssh-add ~/.ssh/id_ed25519
```

---

## Keybindings

- **Ctrl + `** => Quick phrase. Only appears if the keybinding is pressed while typing.
- **f7** => When writing in Japanese, turns text into Katakana (カタカナ).

#### KMonad remapping:

- **Capslock** => SUPER
- **Ctrl** => Tab
- **Tab** => Ctrl
- **Super / Meta** => Esc

#### Script function keys:

- **f12** => Information key. Date and time, Wifi connection, Battery status.
- **f9** => Hyprpicker (Colour picker).

- **print** => Hyprshot (screenshot).
- **PickupPhone** => Decreases mouse sensitivity.
- **HangupPhone** => Increases mouse sensitivity.

#### Hyprland keybindings:

- **Super + Q** => launches terminal (kitty)
- **Super + C** => killactive
- **Super + I** => launches zen browser (Internet browser)
- **Super + E** => launches Nemo (File manager) 
- **Super + V** => Toggle floating
- **Super + R** => Startup fuzzel (launcher)
- **Super + A** => launches Anki (Anki review cards)
- **Super + P** => pseudo (dwindle) focused tile

- **Super + h, l, k, j** => move focus to another tile. h for left, l for right, k for above, j for below.

- **Super + 1 ~ 0** => switch to workspace 1 ~ 10
- **Super + Shift + 1 ~ 0** => move focused tile to workspace 1 ~ 10
- **Super + S** => toggle "special" workspace
- **Super + Shift + S** => move focused tile to "special" workspace

#### fctix5

- **Ctrl + Space** => Toggle Input Method + Enumerate Input Method
- **Ctrl + Shift + Space** => Enumerate Input Method Backwards
