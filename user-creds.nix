{ lib, ... }:

let
  usersList = builtins.fromJSON (builtins.readFile ./secrets/users.json);

  # Turn the JSON list into an attrset
  usersAttrs = builtins.listToAttrs (map (u: {
    name = u.name;
    value =
      (if u ? password then { password = u.password; } else {})
      // (if u ? passwordHash then { passwordHash = u.passwordHash; } else {})
      // { isNormalUser = u.isNormalUser or true; }
      // (if u ? extraGroups then { extraGroups = u.extraGroups; } else {});
  }) usersList);
in
{
  users.users = usersAttrs;
}
