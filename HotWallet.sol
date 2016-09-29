import "lib/StateTransferrable.sol";
import "lib/Token.sol";
import "lib/TrustClient.sol";
import "./Oversight.sol";

/**
 * @title HotWallet contract into which all freshly minted assets end-up. Controlled by Oversight Contract
 *
 * @author Ray Pulver, ray@decentralizedcapital.com
 */
contract HotWallet is StateTransferrable, TrustClient {

  address public oversightAddress;

  mapping (address => uint256) public invoiced;
  address[] public invoicedIndex;
  mapping (address => bool) public invoicedActive;

  event HotWalletDeposit(address indexed from, uint256 amount);
  event PerformedTransfer(address indexed to, uint256 amount);
  event PerformedTransferFrom(address indexed from, address indexed to, uint256 amount);
  event PerformedApprove(address indexed spender, uint256 amount);
  /* ---------------  modifiers  --------------*/

  /**
   * Makes sure the Oversight Contract is set
   */
  modifier onlyWithOversight {
    assert(oversightAddress != 0x0);
    _
  }

  /**
   * Check if the amount of for a certain asset/currency has been approved in the Oversight address
   */
  modifier spendControl(address currency, uint256 amount) {
    assert(Oversight(oversightAddress).validate(currency, amount));
    _
  }

  /**
   * Check if the amount of for a certain asset/currency has been approved in the Oversight address
   * and that the transfer is not to the HotWallet itself
   */
  modifier spendControlTargeted (address currency, address to, uint256 amount) {
    if (to != address(this)) {
      assert(Oversight(oversightAddress).validate(currency, amount));
    }
    _
  }

  /* ---------------  setter methods, only for the unlocked state --------------*/

  /**
   * Sets the Oversight contract address.
   *
   * @param addr Address of the Oversight contract.
   */
  function setOversight(address addr) onlyOwnerUnlocked setter {
    oversightAddress = addr;
  }

  /* --------------- main methods  --------------*/

  /**
   * @notice Transfer `amount` of asset `currency` from the hotwallet to `to`.
   *
   * @param currency Address of the currency/asset.
   * @param to Destination address of the transfer.
   * @param amount The amount to be transferred.
   */
  function transfer(address currency, address to, uint256 amount) multisig(sha3(msg.data)) spendControl(currency, amount) onlyWithOversight {
    Token(currency).transfer(to, amount);
    PerformedTransfer(to, amount);
  }

  /**
   * @notice Transfer `amount` of asset `currency` from `from` to `to`.
   *
   * @param currency Address of the currency/asset.
   * @param from Origin address.
   * @param to Destination address of the transfer.
   * @param amount The amount to be transferred
   */
  function transferFrom(address currency, address from, address to, uint256 amount) multisig(sha3(msg.data)) spendControlTargeted(currency, to, amount) onlyWithOversight {
    Token(currency).transferFrom(from, to, amount);
    PerformedTransferFrom(from, to, amount);
  }

  /**
    * @notice Approve `spender` to transfer `amount` of asset `currency` from the Hotwallet and make a consequential call.
    *
    * @param currency Address of the currency/asset.
    * @param spender Address that receives the cheque/approval to spend
    * @param amount The amount that is approved
    */
  function approve(address currency, address spender, uint256 amount) multisig(sha3(msg.data)) spendControl(currency, amount) onlyWithOversight {
    Token(currency).approve(spender, amount);
    PerformedApprove(spender, amount);
  }

  /**
   * @notice Approve `spender` to transfer `amount` of asset `currency` from the Hotwallet and make a consequential call.
   *
   * @param currency Address of the currency/asset.
   * @param spender Address that receives the cheque/approval to spend
   * @param amount The amount that is approved
   * @param extraData consequential call that is made
   */
  function approveAndCall(address currency, address spender, uint256 amount, bytes extraData) multisig(sha3(msg.data)) spendControl(currency, amount) onlyWithOversight {
    Token(currency).approveAndCall(spender, amount, extraData);
    PerformedApprove(spender, amount);
  }

  /**
   * @notice Receives approval to drain the invoice.
   *
   * @param from Address from which the transfer can be made.
   * @param amount The amount that is approved.
   * @param currency Address of the currency
   * @param extraData consequential call that can be made
   */
  function receiveApproval(address from, uint256 amount, address currency, bytes extraData) external {
    Token(currency).transferFrom(from, this, amount);
    HotWalletDeposit(from, amount);
  }

  /* --------------- methods for siphoning, uploading  --------------*/

  function activateInvoiced(address addr) internal {
    if (!invoicedActive[addr]) {
      invoicedActive[addr] = true;
      invoicedIndex.push(addr);
    }
  }

  function extractInvoicedLength() external returns (uint256 len) {
    return invoicedIndex.length;
  }
}
