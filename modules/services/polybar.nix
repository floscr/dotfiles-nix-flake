{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.polybar;
    polybar = pkgs.polybar.override {
      mpdSupport = true;
      pulseSupport = true;
      nlSupport = true;
    };
in {
  options.modules.services.polybar = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      polybar
      (pkgs.writeScriptBin "toggle-polybar" ''
        if pgrep polybar >/dev/null; then
            systemctl --user stop polybar.service
            bspc config top_padding 0
        else
            systemctl --user start polybar.service
            bspc config top_padding 36
        fi
      '')
    ];

    systemd.user.services.polybar = {
      description = "Polybar daemon";
      after = [ "graphical-session-pre.target" ];
      wantedBy = [ "graphical-session-pre.target" ];
      partOf = [ "graphical-session-pre.target" ];
      restartTriggers = [ "~/.config/polybar/config" ];
      script = ''polybar main &'';
      path = with pkgs; [
        bash
        gawk
        networkmanager
        polybar
        pulseaudio
      ];
      serviceConfig = {
        Type = "forking";
        Restart = "on-failure";
      };
    };

    home.configFile = {
      "polybar" = { source = "${configDir}/polybar"; recursive = true; };
    };
  };
}
