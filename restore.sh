#!/usr/bin/env bash
# Restore Wonder's Arch setup after a clean Arch installation.
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
local_bin="$HOME/.local/bin"
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

if [[ "$(id -u)" -eq 0 ]]; then
    echo "Запускай скрипт обычным пользователем, не через sudo."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    echo "Этот восстановитель рассчитан на Arch Linux."
    exit 1
fi

read_packages() {
    local list_file="$1"
    local -n result="$2"
    mapfile -t result < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$list_file")
}

backup_path() {
    local source="$1"
    local relative="$2"
    if [[ -e "$source" || -L "$source" ]]; then
        mkdir -p "$backup_dir/$(dirname "$relative")"
        cp -a "$source" "$backup_dir/$relative"
    fi
}

echo "==> Проверяю доступ sudo"
sudo -v

echo "==> Обновляю систему и устанавливаю пакеты из официальных репозиториев"
read_packages "$repo_dir/packages-pacman.txt" pacman_packages
sudo pacman -Syu --needed --noconfirm "${pacman_packages[@]}"

if ! command -v paru >/dev/null 2>&1; then
    echo "==> Устанавливаю paru для AUR"
    build_dir="$(mktemp -d)"
    trap 'rm -rf "$build_dir"' EXIT
    git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
    (
        cd "$build_dir/paru"
        makepkg -si --noconfirm
    )
fi

echo "==> Устанавливаю AUR-пакеты"
read_packages "$repo_dir/packages-aur.txt" aur_packages
if ((${#aur_packages[@]})); then
    paru -S --needed --noconfirm "${aur_packages[@]}"
fi

echo "==> Устанавливаю Flatpak-приложения"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
read_packages "$repo_dir/packages-flatpak.txt" flatpak_apps
if ((${#flatpak_apps[@]})); then
    flatpak install --user -y flathub "${flatpak_apps[@]}"
fi

echo "==> Сохраняю заменяемые пользовательские файлы в $backup_dir"
for entry in "$repo_dir/config"/*; do
    name="$(basename "$entry")"
    backup_path "$config_dir/$name" "config/$name"
done
for entry in "$repo_dir/bin"/*; do
    name="$(basename "$entry")"
    [[ "$name" == "roblox-afk.sh" ]] && continue
    backup_path "$local_bin/$name" "local-bin/$name"
done
backup_path "$HOME/.bashrc" "home/.bashrc"
backup_path "$HOME/.bash_profile" "home/.bash_profile"

echo "==> Восстанавливаю конфиги, скрипты, shell, курсор и обои"
mkdir -p "$config_dir" "$local_bin" "$HOME/.local/share/icons"
cp -a "$repo_dir/config/." "$config_dir/"
for entry in "$repo_dir/bin"/*; do
    name="$(basename "$entry")"
    [[ "$name" == "roblox-afk.sh" ]] && continue
    cp -a "$entry" "$local_bin/$name"
done
chmod +x "$local_bin"/*
cp -a "$repo_dir/shell/.bashrc" "$HOME/.bashrc"
cp -a "$repo_dir/shell/.bash_profile" "$HOME/.bash_profile"
cp -a "$repo_dir/assets/cursors/." "$HOME/.local/share/icons/"
"$local_bin/restore-wallpapers"

if [[ -t 0 ]]; then
    echo
    echo "Необязательное дополнение: Roblox AFK-скрипты"
    echo "  • ~/tools/roblox-mini-antiafk.sh — микро-движение раз в 10 минут"
    echo "  • ~/tools/roblox-mini-antiafk-jump.sh — вариант с прыжком"
    echo "  • ~/autoclick.sh — клик раз в 13 минут"
    echo "  • ~/.local/bin/roblox-afk.sh — движение и клики"
    read -r -p "Установить этот набор? [y/N] " install_roblox
    if [[ "$install_roblox" =~ ^[Yy]$ ]]; then
        echo "==> Устанавливаю необязательные Roblox AFK-скрипты"
        backup_path "$HOME/tools/roblox-mini-antiafk.sh" "tools/roblox-mini-antiafk.sh"
        backup_path "$HOME/tools/roblox-mini-antiafk-jump.sh" "tools/roblox-mini-antiafk-jump.sh"
        backup_path "$HOME/autoclick.sh" "home/autoclick.sh"
        backup_path "$local_bin/roblox-afk.sh" "local-bin/roblox-afk.sh"
        mkdir -p "$HOME/tools"
        cp -a "$repo_dir/extras/roblox/roblox-mini-antiafk.sh" "$HOME/tools/"
        cp -a "$repo_dir/extras/roblox/roblox-mini-antiafk-jump.sh" "$HOME/tools/"
        cp -a "$repo_dir/extras/roblox/autoclick.sh" "$HOME/autoclick.sh"
        cp -a "$repo_dir/extras/roblox/roblox-afk.sh" "$local_bin/"
        chmod +x "$HOME/tools/roblox-mini-antiafk.sh" "$HOME/tools/roblox-mini-antiafk-jump.sh" "$HOME/autoclick.sh" "$local_bin/roblox-afk.sh"
    fi
fi

echo "==> Восстанавливаю системные настройки и включаю службы"
if [[ -d "$repo_dir/system/etc" ]]; then
    sudo cp -a "$repo_dir/system/etc/." /etc/
fi
sudo systemctl daemon-reload
for unit in sddm.service systemd-networkd.service systemd-resolved.service systemd-timesyncd.service windscribe-helper.service fstrim.timer; do
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
        sudo systemctl enable "$unit"
    else
        echo "Пропускаю отсутствующую службу: $unit"
    fi
done

echo
echo "Готово. Резервная копия заменённых файлов: $backup_dir"
echo "Перезагрузи компьютер и войди через SDDM."
