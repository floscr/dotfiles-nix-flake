{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.hotplug;
in
{
  options.modules.services.hotplug = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (
    let restartHotplugServiceCmd = "${pkgs.systemd}/bin/systemctl --user restart setup-monitor.service";
    in
    {
      nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

      systemd.user.services."hotplug-monitor@" = {
        enable = true;
        description = "Hotplug Monitor";
        # wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = false;
          ExecStart = restartHotplugServiceCmd;

        };
      };

      systemd.user.services."setup-monitor" = {
        enable = true;
        description = "Load my monitor modifications";
        # after = [ "graphical-session-pre.target" ];
        # wantedBy = [ "graphical-session-pre.target" ];
        # partOf = [ "graphical-session-pre.target" ];
        path = with pkgs; [
          bspwm
          coreutils
          gnugrep
          systemd
          xorg.xrandr
          xorg.xsetroot
          emacsPgtkGcc
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeScript "hotplug-monitor.sh" ''
          #!${pkgs.stdenv.shell}

          function connectLG(){
            xrandr \
              --output eDP-1 --off \
              --output DP-2 \
              --primary \
              --dpi 110 \
              --panning 3840x2160 \
              --mode 3840x2160 \
              --pos 0x0 \
              --rotate normal \
              --auto
          }

          function disconnect(){
            xrandr \
              --output VIRTUAL1 --off \
              --output DP-1 --off \
              --output DP-2 --off \
              --output DP-1 --off \
              --output HDMI-1 --off \
              --output HDMI-2 --off \
              --output eDP-1 \
              --primary \
              --dpi 92 \
              --auto
          }

          if [[ $(xrandr | grep "^DP-2 connected") ]]; then
            connectLG
          else
            disconnect
          fi

          systemctl --user restart polybar.service;

          bspc monitor $MONITOR -d {1,2,3,4,5,6,7}

          # Fix the regular cursor for x
          xsetroot -cursor_name left_ptr

          # Reset windows overlaying polybar
          sleep 1
          emacsclient -e "(+ui|adjust-ui-to-display)"

          # Hacky way to call the script, but it works
          /etc/profiles/per-user/$(whoami)/bin/reloadWallpaper

          ${pkgs.xorg.xrdb}/bin/xrdb -merge ~/.config/xtheme/80-dpi
          bspc config borderless_monocle true
        ''}";
        };
      };

      modules.bindings.items = [
        {
          binding = "F12";
          command = restartHotplugServiceCmd;
          description = "Hotplug Monitor (Old script)";
        }
      ];

      # Jesus christ udev
      # https://superuser.com/a/1401322
      services.udev.extraRules = ''ACTION=="change", KERNEL=="card0", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", ENV{SYSTEMD_USER_WANTS}+="hotplug-monitor@$env{SEQNUM}.service", TAG+="systemd"'';

    }
  );
}
