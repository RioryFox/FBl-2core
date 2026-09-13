{ config, pkgs, ... }:

{
	services.nix-serve = {
		enable = true;
		bindAddress = "0.0.0.0";
		port = 5000;
		secretKeyFile = "/var/lib/nix-serve/cache-key.sec";
		openFirewall = true;
	};

	networking.openFirewall.allowedTCPPorts = 
		if cocnfig.services.nix-serve.enable 
                then [ port ]
                else [ ];
}