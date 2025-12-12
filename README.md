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
|   #   | Preview                                                                                                                                                       | Description                                                                                  |
| :---: | :------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------- |
| **1** | <img width="1921" height="1081" alt="screenshot-2025-11-05_20-59-15" src="https://github.com/user-attachments/assets/552761c3-e9bf-490b-aefc-e21c5dc33d84" /> | 🖼 **Rofi Wallpaper Launcher** — pick your wallpaper instantly with previews.                |
| **2** | <img width="1921" height="1081" alt="screenshot-2025-11-05_21-37-20" src="https://github.com/user-attachments/assets/5b0425b3-afcb-4eac-ad48-be63f143ca17" /> | 🚀 **Rofi App Launcher** — clean and minimal interface for quick app access.                 |
| **3** | <img width="1921" height="1081" alt="screenshot-2025-11-05_21-41-01" src="https://github.com/user-attachments/assets/cc2102f8-2e09-4407-89b8-b8ed437d504f" /> | 🔒 **Wlogout** — sleek logout menu with blur and icons.                                      |
| **4** | <img width="1921" height="1080" alt="screenshot-2025-12-12_19-03-01" src="https://github.com/user-attachments/assets/4df9430e-8c6b-4035-aa90-bcec4b32ea53" /> | 🚀 **Yazi & Fastfetch** — yazi config from [here](https://github.com/RunAtTekky/dotfiles/tree/71747d968fa80817a626275d2f30d294e89e386d/yazi/.config/yazi)         |
| **5** | <img width="1921" height="1081" alt="screenshot-2025-11-11_19-09-56" src="https://github.com/user-attachments/assets/1fd2141c-cd91-4444-8f44-53b7830f80e7" /> | 🎵 **Cava + Spotify + Mako** — Music with visualizer and notification all in Catppuccin theme. |
| **6** | <img width="1921" height="1080" alt="screenshot-2025-11-17_00-12-35" src="https://github.com/user-attachments/assets/a9571c76-6a61-417a-8393-b98ed716b452" /> | 🔔 **Sway Notification Center** - Notifications with Mpris media controls. |




---

## 🧩 Notes

* You’ll need **swww** running before applying wallpapers.
* My setup is on **Fedora + Hyprland**, but you can adapt it to any Wayland-based system.
* Fonts and icons: I use **JetBrainsMono Nerd Font** and **Papirus Icons**.

---

⭐ **If you like the setup, drop a star!** It keeps the vibes high.
