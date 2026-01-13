{...}: {
  imports = [
    ./desktops/hyprland.nix
    ./programs/direnv.nix
    ./programs/ghostty.nix
    ./programs/git.nix
    ./programs/opencode.nix
    ./programs/ssh.nix
    ./programs/starship.nix
    ./programs/zsh.nix
    ./services/dconf.nix
    ./services/gtk.nix
  ];
}
