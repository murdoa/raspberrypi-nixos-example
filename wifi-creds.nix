{ lib, ... }:

let
  wifiList = builtins.fromJSON (builtins.readFile ./secrets/wifi.json);

  wifiAttrs = builtins.listToAttrs (map (n: {
    name = n.ssid;
    value =
      (if n ? psk then { psk = n.psk; } else {})
      // (if n ? pskFile then { pskFile = n.pskFile; } else {})
      // (if n ? hidden then { hidden = n.hidden; } else {})
      // (if n ? priority then { priority = n.priority; } else {});
  }) wifiList);
in
{
  networking.wireless.networks = wifiAttrs;
}
