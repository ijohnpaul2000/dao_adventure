import Debug "mo:base/Debug";
import Map "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

actor Registry {

  stable var entries : [(Text, Nat)] = [];

  let map = Map.fromIter<Text, Nat>(
    entries.vals(),
    10,
    Text.equal,
    Text.hash,
  );

  public func register(name : Text) : async () {
    switch (map.get(name)) {
      case null {
        map.put(name, map.size());
      };
      case (?_id) {};
    };
  };

  public query func getAll() : async [(Text, Nat)] {
    Iter.toArray(map.entries());
  };

  public func lookup(name : Text) : async ?Nat {
    map.get(name);
  };

  system func preupgrade() {
    entries := Iter.toArray(map.entries());

    Debug.print(debug_show (entries));

    for (entry in entries.vals()) {
      Debug.print(debug_show (entry));
    };

  };

  system func postupgrade() {
    entries := [];
  };
};
