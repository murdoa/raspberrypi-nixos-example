{ pkgs, lib, config, ... }:
{
  imports = [
    ./user-creds.nix
    ./wifi-creds.nix
  ];
  
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  boot.extraModulePackages = [ config.boot.kernelPackages.rtl8812au ];

  boot.initrd.checkJournalingFS = false;
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    noCheck = true; # skip fsck on ESP
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    noCheck = false;
  };
  
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [ vim git nftables ];
  services.openssh.enable = true;
  networking.hostName = "nixos";
  users = {
    users.default = {
      password = "default";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
      networks = {
      };
    };
    interfaces."eth0".ipv4.addresses = [
      { address = "192.168.242.1"; prefixLength = 24; }
    ];
    nat = {
      enable = true;
      externalInterface = "wlan0";
      internalInterfaces = [ "eth0" ];
    };
    firewall = {
      enable = true;
      allowPing = true;
      checkReversePath = "loose";
      # don't open DHCP globally
      allowedUDPPorts = [ ];
      allowedTCPPorts = [ ];

      interfaces.eth0 = {
        allowedUDPPorts = [ 53 67 68 8443 3478 10001 8080 8843 8880 1900 5514 123 ]; # DNS + DHCP
        allowedTCPPorts = [ 53 8443 8080 8843 8880 6789 ];       # DNS over TCP
      };
    };
  };
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "eth0";
      port = 0; # disable DNS
      dhcp-range = "192.168.242.100,192.168.242.200,12h";
      dhcp-option = [
        "3,192.168.242.1" # gateway
        "6,192.168.242.1" # DNS -> unbound
      ];
    };
  };
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "0.0.0.0" "::0" ];
        access-control = [ "192.168.242.0/24 allow" ];
        hide-identity = true;
        hide-version = true;

        # Turn off all DNSSEC validation
        val-clean-additional = false;
        val-permissive-mode = true;
        module-config = "iterator"; # disable validator module entirely
      };

      forward-zone = [{
        name = ".";
        forward-addr = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      }];
    };
  };
  services.gpsd = {
    enable = true;
    devices = [ "/dev/ttyACM0" ];
    nowait = true;     # do not wait for clients, always poll GPS → ensures SHM is populated. :contentReference[oaicite:2]{index=2}
    listenany = false; # whether gpsd listens on all network interfaces; default is probably just localhost. Adjust if you need remote. :contentReference[oaicite:3]{index=3}
    extraArgs = [ "-n" ];  # alias for nowait — sometimes duplicate depending on version, but extraArgs ensures gpsd gets the flag.  
  };
  services.chrony = {
    enable = true;
    servers = [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" ];  # pick good ones for your region

    extraConfig = ''
      # Use shared memory segment 0 from gpsd (NMEA + PPS if available)
      refclock SHM 0 refid GPS precision 1e-1 poll 4

      # If gpsd provides separate PPS in SHM 1, you could also do:
      # refclock SHM 1 refid PPS precision 1e-7 poll 4

      # Allow clients on your LAN to use this chrony server
      allow 192.168.242.0/24

      # If the clock is off by more than 1 second, allow stepping for first 3 updates
      makestep 1.0 3
    '';
  };

  services.vnstat.enable = true;

  # Not enough RAM on pi3 for telemetry
  # services.netdata.enable = true;
  # services.prometheus = {
  #   enable = true;
  #   exporters.node = {
  #     enable = true;
  #     port = 9100;
  #   };
  # };
  # services.grafana = {
  #   enable = true;
  #   settings.server.http_port = 3000;
  #   provision.enable = true;
  # };

  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [ "root" "@wheel" ];
  };
  system.stateVersion = "25.11";
}
