{ config, ... }:

{
  services.suricata = {
    enable = true;
    settings = {
      af-packet = [
        {
          interface = config.fbl.network.interfaces.cr01Lan;
        }
      ];
      vars = {
        adresses-groups.HOME_NET = config.fbl.network.lan.cidr;
        port-groups = {
          DNP3_PORTS = "20000";
          FILE_DATA_PORTS = "[$HTTP_PORTS,110,143]";
          FTP_PORTS = "21";
          GENEVE_PORTS = "6081";
          HTTP_PORTS = toString config.fbl.ports.tcp.http;
          MODBUS_PORTS = "502";
          ORACLE_PORTS = "1521";
          SHELLCODE_PORTS = "!80";
          SSH_PORTS = oString config.fbl.ports.tcp.ssh;
          TEREDO_PORTS = "3544";
          VXLAN_PORTS = "4789";
      };
    };
  };
}