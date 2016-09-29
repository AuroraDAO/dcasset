import "lib/TrustClient.sol";
import "lib/StateTransferrable.sol";
import "./DCAsset.sol";
import "./DCAssetBackend.sol";

/**
 * @title Oversight Contract that is hooked into HotWallet to provide extra security.
 *
 * @author Ray Pulver, ray@decentralizedcapital.com
 */
contract Oversight is StateTransferrable, TrustClient {

  address public hotWalletAddress;

  mapping (address => uint256) public approved;             //map of approved amounts per currency
  address[] public approvedIndex;                           //array of approved currencies

  mapping (address => uint256) public expiry;               //map of expiry times per currency

  mapping (address => bool) public currencyActive;          //map of active/inactive currencies

  mapping (address => bool) public oversightAddresses;      //map of active/inactive oversight addresses
  address[] public oversightAddressesIndex;                 //array of oversight addresses

  mapping (address => bool) public oversightAddressActive;  //map of active oversight addresses (for siphoning/uploading)

  uint256 public timeWindow;                                //expiry time for an approval

  event TransactionsShutDown(address indexed from);

  /**
   * Constructor. Sets expiry to 10 minutes.
   */
  function Oversight() {
    timeWindow = 10 minutes;
  }

  /* ---------------  modifiers  --------------*/

  /**
   * Makes sure a method is only called by an overseer.
   */
  modifier onlyOverseer {
    assert(oversightAddresses[msg.sender]);
    _
  }

  /**
   * Makes sure a method is only called from the HotWallet.
   */
  modifier onlyHotWallet {
    assert(msg.sender == hotWalletAddress);
    _
  }

  /* ---------------  setter methods, only for the unlocked state --------------*/

  /**
   * Sets the HotWallet address.
   *
   * @param addr Address of the hotwallet.
   */
  function setHotWallet(address addr) onlyOwnerUnlocked setter {
      hotWalletAddress = addr;
  }

  /**
   * Sets the approval expiry window, called before the contract is locked.
   *
   * @param secs Expiry time in seconds.
   */
  function setupTimeWindow(uint256 secs) onlyOwnerUnlocked setter {
    timeWindow = secs;
  }

  /**
   * Approves an amount for a certain currency, called before the contract is locked.
   *
   * @param addr Currency.
   * @param amount The amount to approve.
   */
  function setApproved(address addr, uint256 amount) onlyOwnerUnlocked setter {
    activateCurrency(addr);
    approved[addr] = amount;
  }

  /**
   * Sets the expiry window for a certain currency, called before the contracted is locked.
   *
   * @param addr Currency.
   * @param ts Window in seconds
   */
  function setExpiry(address addr, uint256 ts) onlyOwnerUnlocked setter {
    activateCurrency(addr);
    expiry[addr] = ts;
  }

  /**
   * Sets an oversight address, on active or inactive, called before the contract is locked.
   *
   * @param addr The oversight address.
   * @param value Whether to activate or deactivate the address.
   */
  function setOversightAddress(address addr, bool value) onlyOwnerUnlocked setter {
    activateOversightAddress(addr);
    oversightAddresses[addr] = value;
  }



  /* ---------------  multisig admin methods  --------------*/

  /**
   * @notice Sets the approval expiry window to `secs`.
   *
   * @param secs Expiry time in seconds.
   */
  function setTimeWindow(uint256 secs) external multisig(sha3(msg.data)) {
    timeWindow = secs;
  }

  /**
   * @notice Adds and activates new oversight address `addr`.
   *
   * @param addr The oversight addresss.
   */
  function addOversight(address addr) external multisig(sha3(msg.data)) {
    activateOversightAddress(addr);
    oversightAddresses[addr] = true;
  }

  /**
   * @notice Removes/deactivates oversight address `addr`.
   *
   * @param addr The oversight address to be removed.
   */
  function removeOversight(address addr) external multisig(sha3(msg.data)) {
    oversightAddresses[addr] = false;
  }

  /* ---------------  multisig main methods  --------------*/

  /**
   * @notice Approve `amount` of asset `currency` to be withdrawn.
   *
   * @param currency Address of the currency/asset to approve a certain amount for.
   * @param amount The amount to approve.
   */
  function approve(address currency, uint256 amount) external multisig(sha3(msg.data)) {
    activateCurrency(currency);
    approved[currency] = amount;
    expiry[currency] = now + timeWindow;
  }

  /* ---------------  method for hotwallet  --------------*/

  /**
   * @notice Validate that `amount` is allowed to be transacted for `currency`.
   * Called by the HotWallet to validate a transaction.
   *
   * @param currency Address of the currency/asset for which is validated.
   * @param amount The amount that is validated.
   */
  function validate(address currency, uint256 amount) external onlyHotWallet returns (bool) {
    assert(approved[currency] >= amount);
    approved[currency] -= amount;
    return true;
  }

  /* ---------------  Overseer methods for emergency --------------*/

  /**
   * @notice Shutdown transactions on asset `currency`
   *
   * @param currency Address of the currency/asset contract to be shut down.
   */
  function shutdownTransactions(address currency) onlyOverseer {
    address backend = DCAsset(currency).backendContract();
    DCAssetBackend(backend).shutdownTransactions();
    TransactionsShutDown(msg.sender);
  }

  /* ---------------  Helper methods for siphoning --------------*/

  /**
   * Returns the amount of approvals.
   */
  function extractApprovedIndexLength() returns (uint256) {
    return approvedIndex.length;
  }

  /**
   * Returns the amount of oversight addresses.
   */
  function extractOversightAddressesIndexLength() returns (uint256) {
    return oversightAddressesIndex.length;
  }

  /* ---------------  private methods --------------*/

  function activateOversightAddress(address addr) internal {
    if (!oversightAddressActive[addr]) {
      oversightAddressActive[addr] = true;
      oversightAddressesIndex.push(addr);
    }
  }

  function activateCurrency(address addr) internal {
    if (!currencyActive[addr]) {
      currencyActive[addr] = true;
          approvedIndex.push(addr);
    }
  }

}
