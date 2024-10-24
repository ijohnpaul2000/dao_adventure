import MBCToken "canister:graduation_token";
import Webpage "canister:graduation_webpage";

import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Types "types";
actor {

  type Result<A, B> = Result.Result<A, B>;
  type Member = Types.Member;
  type ProposalContent = Types.ProposalContent;
  type ProposalId = Types.ProposalId;
  type Proposal = Types.Proposal;
  type Vote = Types.Vote;
  type HttpRequest = Types.HttpRequest;
  type HttpResponse = Types.HttpResponse;

  stable let canisterIdWebpage : Principal = Principal.fromText("5oxzc-3qaaa-aaaab-qaczq-cai");
  stable var manifesto = "JP Dao is a DAO for the JP community that aims to help students graduate and become mentors. The DAO is governed by mentors who can propose changes to the manifesto, add goals, and vote on proposals. Students can graduate to become mentors. The DAO is powered by the MBC token.";
  stable let name = "jpDAO";
  stable var goals = [];
  stable var next_proposal_id : Nat = 0;
  stable let voting_power_multiplier : Nat = 5;
  stable var membersEntries : [(Principal, Member)] = [];
  stable var proposalsEntries : [(ProposalId, Proposal)] = [];

  func natHash(n : Nat) : Nat32 {
    var x = Nat32.fromNat(n);
    x := ((x >> 16) ^ x) *% 0x45d9f3b;
    x := ((x >> 16) ^ x) *% 0x45d9f3b;
    x := (x >> 16) ^ x;
    return x;
  };

  let proposals = HashMap.HashMap<ProposalId, Proposal>(10, Nat.equal, natHash);

  let initialMentorPrincipal : Principal = Principal.fromText("nkqop-siaaa-aaaaj-qa3qq-cai");
  let initialMentorName : Text = "motoko_bootcamp";

  private func initMembers() : HashMap.HashMap<Principal, Member> {
    let m = HashMap.HashMap<Principal, Member>(10, Principal.equal, Principal.hash);
    m.put(initialMentorPrincipal, { name = initialMentorName; role = #Mentor });
    m;
  };

  var members = initMembers();

  system func preupgrade() {
    membersEntries := Iter.toArray(members.entries());
    proposalsEntries := Iter.toArray(proposals.entries());
  };

  system func postupgrade() {
    members := HashMap.fromIter<Principal, Member>(membersEntries.vals(), 10, Principal.equal, Principal.hash);
    for ((id, proposal) in proposalsEntries.vals()) {
      proposals.put(id, proposal);
    };

    switch (members.get(initialMentorPrincipal)) {
      case null {
        members.put(initialMentorPrincipal, { name = initialMentorName; role = #Mentor });
      };
      case (?_) {};
    };
  };

  public query func getName() : async Text {
    return name;
  };

  public query func getManifesto() : async Text {
    return manifesto;
  };

  public query func getGoals() : async [Text] {
    return Iter.toArray(goals.vals());
  };

  public shared ({ caller }) func registerMember(member : Member) : async Result<(), Text> {
    switch (members.get(caller)) {
      case (null) {
        let new_member : Member = {
          name = member.name;
          role = #Student;
        };

        ignore await MBCToken.mint(caller, 10);

        members.put(caller, new_member);

        return #ok();
      };
      case (?member) {
        return #err("Member already exist.");
      };
    };
  };

  public query func getMember(p : Principal) : async Result<Member, Text> {
    switch (members.get(p)) {
      case (null) {
        return #err("Member does not exist.");
      };
      case (?member) {
        return #ok(member);
      };
    };
  };

  public shared ({ caller }) func graduate(student : Principal) : async Result<(), Text> {

    switch (members.get(caller)) {
      case (null) {
        return #err("Student does not exist.");
      };
      case (?member) {
        if (member.role != #Student) {
          return #err("Member is not a student.");
        } else if (member.role != #Mentor) {
          return #err("Caller is not a mentor.");
        } else {
          let new_member : Member = {
            name = member.name;
            role = #Graduate;
          };

          members.put(student, new_member);

          return #ok();
        };
      };
    };
  };

  public shared ({ caller }) func createProposal(content : ProposalContent) : async Result<ProposalId, Text> {
    switch (members.get(caller)) {
      case (null) {
        return #err("Member does not exist.");
      };
      case (?member) {
        if (member.role != #Mentor) {
          return #err("You are not authorized to create a proposal.");
        } else {
          let proposal_id = next_proposal_id;

          next_proposal_id += 1;

          let new_proposal : Proposal = {
            id = proposal_id;
            content = content;
            creator = caller;
            created = Time.now();
            executed = null;
            votes = [];
            voteScore = 0;
            status = #Open;
          };

          ignore await MBCToken.burn(caller, 1);

          proposals.put(proposal_id, new_proposal);

          return #ok(proposal_id - 1);
        };
      };
    };
    return #err("Not implemented");
  };

  public query func getProposal(id : ProposalId) : async Result<Proposal, Text> {

    switch (proposals.get(id)) {
      case (null) {
        return #err("Proposal does not exist.");
      };
      case (?proposal) {
        return #ok(proposal);
      };
    };
  };

  public query func getAllProposal() : async [Proposal] {
    return Iter.toArray(proposals.vals());
  };

  private func updateManifesto(newManifesto : Text) : async Result<(), Text> {
    manifesto := newManifesto;
    let webpageActor = actor (Principal.toText(canisterIdWebpage)) : actor {
      setManifesto : shared (Text) -> async Result<(), Text>;
    };
    try {
      let result = await Webpage.setManifesto(newManifesto);
      ignore await webpageActor.setManifesto(newManifesto);
      switch (result) {
        case (#ok(())) {
          Debug.print("Manifesto updated successfully in Webpage canister.");
          #ok(());
        };
        case (#err(message)) {
          Debug.print("Failed to update manifesto in Webpage canister: " # message);
          #err("Failed to update manifesto in Webpage canister: " # message);
        };
      };
    } catch (error) {
      let errorMessage = "Error calling Webpage canister: " # Error.message(error);
      Debug.print(errorMessage);
      #err(errorMessage);
    };
  };

  private func executeProposal(proposal : Proposal) : async () {
    switch (proposal.content) {
      case (#ChangeManifesto(newManifesto)) {
        let updateResult = await updateManifesto(newManifesto);
        switch (updateResult) {
          case (#ok(())) {
            Debug.print("Manifesto successfully updated to: " # newManifesto);
          };
          case (#err(message)) {
            Debug.print("Execution failed for ChangeManifesto: " # message);
          };
        };
      };
      case (#AddMentor(newMentorPrincipal)) {
        switch (members.get(newMentorPrincipal)) {
          case (?member) {
            if (member.role == #Graduate) {
              members.put(newMentorPrincipal, { name = member.name; role = #Mentor });
              Debug.print("Mentor role assigned to: " # Principal.toText(newMentorPrincipal));
            } else {
              Debug.print("Error: Only graduates can be promoted to mentor");
            };
          };
          case (null) {
            Debug.print("Error: Member not found when trying to add mentor");
          };
        };
      };
      case (#AddGoal(_goal)) {
        // Handle AddGoal proposal if needed
      };
    };
  };

  public shared ({ caller }) func voteProposal(proposalId : ProposalId, yesOrNo : Bool) : async Result<(), Text> {

    switch (members.get(caller)) {
      case (null) {
        return #err("Member does not exist.");
      };
      case (?member) {
        var voting_power = 0;
        var balance = await MBCToken.balanceOf(caller);

        if (member.role == #Student) {
          return #err("You are not allowed to vote.");
        };

        switch (member.role) {
          case (#Student) {
            voting_power := 0;
          };
          case (#Graduate) {
            voting_power := balance;
          };
          case (#Mentor) {
            voting_power := balance * voting_power_multiplier;
          };
        };

        switch (proposals.get(proposalId)) {
          case (null) {
            return #err("Proposal does not exist.");
          };
          case (?proposal) {
            if (proposal.status != #Open) {
              return #err("Proposal is not open for voting");
            };

            let new_vote : Vote = {
              member = caller;
              votingPower = voting_power;
              yesOrNo = yesOrNo;
            };

            let new_vote_score = if (yesOrNo) {
              voting_power + proposal.voteScore;
            } else {
              if (proposal.voteScore >= voting_power) {
                proposal.voteScore - voting_power;
              } else {
                0; // Prevent underflow
              };
            };

            let new_votes = Array.append(proposal.votes, [new_vote]);
            let new_status = (
              if (new_vote_score >= 100) {
                #Accepted;
              } else if (new_vote_score <= 0) {
                #Rejected;
              } else {
                #Open;
              }
            );

            var should_execute = false;

            if (new_status == #Accepted) {
              should_execute := true;
            };

            let updated_proposal : Proposal = {
              id = proposal.id;
              content = proposal.content;
              creator = proposal.creator;
              created = proposal.created;
              executed = if (should_execute) { ?Time.now() } else { null };
              votes = new_votes;
              voteScore = new_vote_score;
              status = new_status;
            };

            proposals.put(proposalId, updated_proposal);

            await executeProposal(updated_proposal);

            return #ok();

          };
        };
      };
    };
  };

  public query func getIdWebpage() : async Principal {
    return canisterIdWebpage;
  };

};
