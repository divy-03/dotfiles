# 🌙 My Dotfiles

Welcome to my **dotfiles repo** — aka the soul of my Linux setup 💻✨
This is where all the magic happens: Hyprland configs, Waybar themes, Rofi menus, and other tweaks that make my system *feel like home*.

---

## 🚀 Getting Started

Clone the repo (I use SSH, but HTTPS works too):

```bash
git clone git@github.com:divy-03/dotfiles.git
cd dotfiles
```

### 🪄 Linking Configs

I use [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks easily — it keeps everything modular and clean.

To link a config (example: `waybar`):

```bash
stow waybar
```

To unlink a config (say you’re testing something new):

```bash
stow -D waybar
```

That’s it. Stow handles all the symlinks for you. 🙌

---

## 🖼️ Screenshots

|   #   | Preview                                                                                                                                                       | Description                                                                         |
| :---: | :------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------- |
| **1** | <img width="1921" height="1081" alt="screenshot-2025-11-05_20-59-15" src="https://github.com/user-attachments/assets/552761c3-e9bf-490b-aefc-e21c5dc33d84" /> | 🖼 **Rofi Wallpaper Launcher** — pick your wallpaper instantly with previews.       |
| **2** | <img width="1921" height="1081" alt="screenshot-2025-11-05_21-37-20" src="https://github.com/user-attachments/assets/5b0425b3-afcb-4eac-ad48-be63f143ca17" /> | 🚀 **Rofi App Launcher** — clean and minimal interface for quick app access.        |
| **3** | <img width="1921" height="1081" alt="screenshot-2025-11-05_21-41-01" src="https://github.com/user-attachments/assets/cc2102f8-2e09-4407-89b8-b8ed437d504f" /> | 🔒 **Wlogout** — sleek logout menu with blur and icons.                             |
| **4** | <img width="1921" height="1081" alt="screenshot-2025-11-05_21-42-52" src="https://github.com/user-attachments/assets/09f819d2-0218-4d22-9de5-be96e8d9105b" /> | 🖥 **Terminal Setup** — `btop++`, `cava`, and `fastfetch` for system stats & vibes. |

---

## 🧩 Notes

* You’ll need **swww** running before applying wallpapers.
* My setup is on **Fedora + Hyprland**, but you can adapt it to any Wayland-based system.
* Fonts and icons: I use **JetBrainsMono Nerd Font** and **Papirus Icons**.

---

⭐ **If you like the setup, drop a star!** It keeps the vibes high.
