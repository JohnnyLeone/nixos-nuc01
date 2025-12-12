{ config, lib, pkgs, ... }:


let
  ovmf = pkgs.OVMFFull.fd;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "netdata"
  ];

  services.netdata.package = pkgs.netdata.override {
    withCloudUi = true;
  };

  ########################
  # Basic system settings
  ########################

  boot.kernelModules = [ "coretemp" ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.editor = true;

  networking = {
    hostName = "nuc01";

    networkmanager.enable = false;
    useNetworkd = true;

    useDHCP = false;

    enableIPv6 = false;

    ############################
    # Bridges for host & guests
    ############################

    bridges.hostbr0.interfaces = [ "eno1" ];

    bridges.guestbr0.interfaces = [ "thunderbolt0.1" ];

    ############################
    # VLANs
    ############################

    vlans."hostbr0.41" = {
      id = 41;
      interface = "hostbr0";
    };

    vlans."hostbr0.44" = {
      id = 44;
      interface = "hostbr0";
    };

    vlans."thunderbolt0.1" = {
      id = 1;
      interface = "thunderbolt0";
    };

    ############################
    # IP configuration
    ############################

    interfaces.hostbr0.useDHCP = true;

    interfaces.thunderbolt0.ipv4.addresses = [
      { address = "192.168.40.21"; prefixLength = 24; }
    ];

    interfaces.eno1.useDHCP = false;
    interfaces."thunderbolt0.1".useDHCP = false;

    firewall.enable = false;
  };

  time.timeZone = "Europe/Berlin";

  ########################
  # User + SSH
  ########################

  users.users.ahs = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" "kvm" ];
    packages = with pkgs; [
      tree
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCh31jo3CJ125IAmWKeqs/2UzdbZIrioQB1AZwAmP03hREHgDRX5MXjyUIVheXBoaRS3aWrerWAfxnvK/VESx6Y4Xd/2lgNUpqnJmNj1z8PjQp1shXQhVxk2HR1/kmaAB3mX5rJRh5WLFF83k6+52+0HBXw4PyDAo+jqrD5HSOQldsRn/Xe4knUHpgv1LUm77oZOeWJdQNvRN2XHsKYbxBeTiFlbJ+yKwBUr6kh0wDJNcTPQLiAuDtUGXBbysLrs1doAacajieIizaBupFJvsV88+iIDuh5AbAhehQGo4r4Q1IREW0ziMmIKWarH6ngadhKIIKGaG875tQfNZ5/o9uuCrGycHcKs6IF/4rLgMFibeNmTf/xcovdUsGNunkYkUJ6z6totVKzVrS/NCUxT41qlXTWlwCMOd/RCZSUc/ZpX3Htrt5+RmP3/sfOp6PvOzKNuYqsz6bDpFbZby2FaBZCBmcwKJbTQsQij3CudGBjbuDXKforRpuuzZn/mVYs5QM= ahirschauer@Andreass-MacBook-Pro.local"
    ];
  };

  security.sudo.enable = true;
  # Pick what you prefer:
  # security.sudo.wheelNeedsPassword = true;  # safer
  security.sudo.wheelNeedsPassword = false;   # convenient

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;  # key-only SSH
      PermitRootLogin = "yes";
    };
  };

  ########################
  # Cockpit Web GUI
  ########################

  services.cockpit = {
    enable = true;

    # Work around NixOS Cockpit websocket/origin bug and allow browser access.
    # Adjust hostnames/IPs as needed.
    settings.WebService.Origins = lib.mkForce ''
      http://localhost:9090
      https://localhost:9090
      https://nuc01:9090
      https://nuc01.intranet.hirschauer-it.de:9090
      https://192.168.42.21:9090
    '';
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2005-10.org.nixos.ctl:nuc01";
  };

  ########################
  # Virtualisation: libvirt/KVM
  ########################

  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "shutdown";
    parallelShutdown = 4;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = with pkgs; [ virtiofsd ];
    };
  };

  ########################
  # Docker
  ########################

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;

    daemon.settings = {
      "data-root" = "/data/docker/data-root";
    };

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  ########################
  # Netdata
  ########################

  services.netdata = {
    enable = true;
    config.global = {
      "memory mode" = "ram";
      "debug log" = "none";
      "access log" = "none";
      "error log" = "syslog";
    };
  };

  ########################
  # /data directory layout
  ########################

  systemd.tmpfiles.rules = [
    "d /data 0755 root root -"
    "d /data/docker 0755 root root -"
    "d /data/docker/compose 0755 root root -"
    "d /data/docker/volumes 0755 root root -"
    "d /data/docker/data-root 0755 root root -"

    "d /data/libvirt 0755 root root -"
    "d /data/libvirt/isos 0755 root root -"
    "d /data/libvirt/disks 0755 root root -"
    "d /data/libvirt/saved_vms 0755 root root -"

    "L+ /usr/bin/qemu-system-x86_64 - - - - ${pkgs.qemu_kvm}/bin/qemu-system-x86_64"
    "d /usr/share 0755 root root -"
    "d /usr/share/edk2 0755 root root -"
    "d /usr/share/edk2/x64 0755 root root -"
    "L+ /usr/share/edk2/x64/OVMF_CODE.4m.fd - - - - ${ovmf}/FV/OVMF_CODE.fd"
    "L+ /usr/share/edk2/x64/OVMF_VARS.4m.fd - - - - ${ovmf}/FV/OVMF_VARS.fd"
    "L+ /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd - - - - ${ovmf}/FV/OVMF_CODE.fd"
    "L+ /usr/share/edk2/x64/OVMF_VARS.secboot.4m.fd - - - - ${ovmf}/FV/OVMF_VARS.fd"
  ];

  ########################
  # Bind mounts for libvirt
  ########################

  fileSystems."/var/lib/libvirt/images" = {
    device = "/data/libvirt/disks";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/libvirt/isos" = {
    device = "/data/libvirt/isos";
    fsType = "none";
    options = [ "bind" ];
  };

  ########################
  # Minimal packages
  ########################

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    docker-compose
    cockpit
    libvirt
    libvirt-dbus
    openiscsi
    lm_sensors
    s-tui
    iperf3
    iftop
    swtpm
    virtiofsd
  ];

  ########################
  # Nix settings
  ########################

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "25.11";
}
