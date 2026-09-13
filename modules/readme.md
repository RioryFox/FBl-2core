Держи файл - тут опиши что 
ports.nix - место где за сервисом закрепляются порт

а при сощздании сервиса примерняется подход формата networking.openFirewall.allowedTCPPorts = 
		if cocnfig.services.nix-serve.enable 
                then [ port ]
                else [ ];

                