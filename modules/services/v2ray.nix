{ config, pkgs, ... }:

{
        services.v2raya = {
                enable = true;
                cliPackage = pkgs.xray;
        };

        networking.firewall = {
                enable = true;
                allowedTCPPorts =
                        if config.services.qbittorrent.enable
                        then [ ]
                        else [ ];
                allowedUDPPorts =
                        if config.services.qbittorrent.enable
                        then [  ]
                        else [ ];     
        };   
}