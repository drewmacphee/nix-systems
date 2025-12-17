{ config, pkgs, ... }:

{
  # Base packages for all users
  home.packages = with pkgs; [
    gawk
    google-chrome
    vlc
    libreoffice
    gimp
  ];
}
