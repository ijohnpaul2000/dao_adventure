import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

import Types "types";

actor Webpage {
  type Result<A, B> = Result.Result<A, B>;
  type HttpRequest = Types.HttpRequest;
  type HttpResponse = Types.HttpResponse;

  stable var manifesto : Text = "Let's graduate!";
  stable let canisterIdDao : Principal = Principal.fromText("5avuk-aaaaa-aaaab-qacyq-cai");

  public query func http_request(request : HttpRequest) : async HttpResponse {
    return {
      status_code = 200; // Changed from 404 to 200
      headers = [("Content-Type", "text/plain")];
      body = Text.encodeUtf8(manifesto);
      streaming_strategy = null;
    };
  };

  public shared ({ caller }) func setManifesto(newManifesto : Text) : async Result<(), Text> {
    if (caller != canisterIdDao) {
      return #err("Unauthorized");
    };
    manifesto := newManifesto;
    Debug.print("New manifesto: " # newManifesto);
    return #ok();
  };
};
