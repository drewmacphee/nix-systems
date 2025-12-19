{ config, pkgs, pkgs-unstable, ... }:

{
  # Development tools for admin users
  home.packages = with pkgs; [
    python3
    nodejs
    git
  ];
  
  # VS Code with extensions and settings - using unstable for latest version
  programs.vscode = {
    enable = true;
    package = pkgs-unstable.vscode;
    extensions = with pkgs-unstable.vscode-extensions; [
      ms-python.python
      ms-vscode-remote.remote-ssh
      jnoortheen.nix-ide
    ];
    userSettings = {
      "update.mode" = "none";
      "extensions.autoUpdate" = false;
      "git.enableSmartCommit" = true;
    };
  };
}
