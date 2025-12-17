{ config, pkgs, ... }:

{
  # Base packages for all users
  home.packages = with pkgs; [
<<<<<<< HEAD
=======
    gawk
    google-chrome
>>>>>>> 96a75799e5d2ba0edc953bfb292a28e474186aa1
    vlc
    libreoffice
    gimp
  ];
  
  # Google Chrome with proper configuration
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
    commandLineArgs = [
      "--enable-features=VaapiVideoDecoder"
      "--enable-gpu-rasterization"
    ];
  };
}
