import "./lib/StateTransferrable.sol";
import "./lib/TrustEvents.sol";

/**
 * @title Trust Contract, providing multisig security to list of client contracts.
 *
 * @author Ray Pulver, ray@decentralizedcapital.com
 */
contract Trust is StateTransferrable, TrustEvents {

  mapping (address => bool) public masterKeys;
  mapping (address => bytes32) public nameRegistry;
  address[] public masterKeyIndex;
  mapping (address => bool) public masterKeyActive;
  mapping (address => bool) public trustedClients;
  mapping (uint256 => address) public functionCalls;
  mapping (address => uint256) public functionCalling;

  /* ---------------  modifiers  --------------*/

  modifier multisig (bytes32 hash) {
    if (!masterKeys[msg.sender]) {
      Unauthorized(msg.sender);
    } else if (functionCalling[msg.sender] == 0) {
      if (functionCalls[uint256(hash)] == 0x0) {
        functionCalls[uint256(hash)] = msg.sender;
        functionCalling[msg.sender] = uint256(hash);
        AuthInit(msg.sender);
      } else {
        AuthComplete(functionCalls[uint256(hash)], msg.sender);
        resetAction(uint256(hash));
        _
      }
    } else {
      AuthPending(msg.sender);
    }
  }

  /* ---------------  setter methods, only for the unlocked state --------------*/

  /**
   * @notice Sets a master key
   *
   * @param addr Address
   */
  function setMasterKey(address addr) onlyOwnerUnlocked {
    assert(!masterKeys[addr]);
    activateMasterKey(addr);
    masterKeys[addr] = true;
    SetMasterKey(msg.sender);
  }

  /**
   * @notice Adds a trusted client
   *
   * @param addr Address
   */
  function setTrustedClient(address addr) onlyOwnerUnlocked setter {
    trustedClients[addr] = true;
  }

  /* ---------------  methods to be called by a Master Key  --------------*/



  /* ---------------  multisig admin methods  --------------*/

  /**
   * @notice remove contract `addr` from the list of trusted contracts
   *
   * @param addr Address of client contract to be removed
   */
  function untrustClient(address addr) multisig(sha3(msg.data)) {
    trustedClients[addr] = false;
  }

  /**
   * @notice add contract `addr` to the list of trusted contracts
   *
   * @param addr Address of contract to be added
   */
  function trustClient(address addr) multisig(sha3(msg.data)) {
    trustedClients[addr] = true;
  }

  /**
   * @notice remove key `addr` to the list of master keys
   *
   * @param addr Address of the masterkey
   */
  function voteOutMasterKey(address addr) multisig(sha3(msg.data)) {
    assert(masterKeys[addr]);
    masterKeys[addr] = false;
  }

  /**
   * @notice add key `addr` to the list of master keys
   *
   * @param addr Address of the masterkey
   */
  function voteInMasterKey(address addr) multisig(sha3(msg.data)) {
    assert(!masterKeys[addr]);
    activateMasterKey(addr);
    masterKeys[addr] = true;
  }

  /* ---------------  methods to be called by Trusted Client Contracts  --------------*/


  /**
   * @notice Cancel outstanding multisig method call from address `from`. Called from trusted clients.
   *
   * @param from Address that issued the call that needs to be cancelled
   */
  function authCancel(address from) external returns (uint8 status) {
    if (!masterKeys[from] || !trustedClients[msg.sender]) {
      Unauthorized(from);
      return 0;
    }
    uint256 call = functionCalling[from];
    if (call == 0) {
      NothingToCancel(from);
      return 1;
    } else {
      AuthCancel(from, from);
      functionCalling[from] = 0;
      functionCalls[call] = 0x0;
      return 2;
    }
  }

  /**
   * @notice Authorize multisig call on a trusted client. Called from trusted clients.
   *
   * @param from Address from which call is made.
   * @param hash of method call
   */
  function authCall(address from, bytes32 hash) external returns (uint8 code) {
    if (!masterKeys[from] || !trustedClients[msg.sender]) {
      Unauthorized(from);
      return 0;
    }
    if (functionCalling[from] == 0) {
      if (functionCalls[uint256(hash)] == 0x0) {
        functionCalls[uint256(hash)] = from;
        functionCalling[from] = uint256(hash);
        AuthInit(from);
        return 1;
      } else {
        AuthComplete(functionCalls[uint256(hash)], from);
        resetAction(uint256(hash));
        return 2;
      }
    } else {
      AuthPending(from);
      return 3;
    }
  }

  /* ---------------  methods to be called directly on the contract --------------*/

  /**
   * @notice cancel any outstanding multisig call
   *
   */
  function cancel() returns (uint8 code) {
    if (!masterKeys[msg.sender]) {
      Unauthorized(msg.sender);
      return 0;
    }
    uint256 call = functionCalling[msg.sender];
    if (call == 0) {
      NothingToCancel(msg.sender);
      return 1;
    } else {
      AuthCancel(msg.sender, msg.sender);
      uint256 hash = functionCalling[msg.sender];
      functionCalling[msg.sender] = 0x0;
      functionCalls[hash] = 0;
      return 2;
    }
  }

  /* ---------------  private methods --------------*/

  function resetAction(uint256 hash) internal {
    address addr = functionCalls[hash];
    functionCalls[hash] = 0x0;
    functionCalling[addr] = 0;
  }

  function activateMasterKey(address addr) internal {
    if (!masterKeyActive[addr]) {
      masterKeyActive[addr] = true;
      masterKeyIndex.push(addr);
    }
  }

  /* ---------------  helper methods for siphoning --------------*/

  function extractMasterKeyIndexLength() returns (uint256 length) {
    return masterKeyIndex.length;
  }

}
