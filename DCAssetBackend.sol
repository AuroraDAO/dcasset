import "lib/Token.sol";
import "lib/TokenRecipient.sol";
import "lib/StateTransferrable.sol";
import "lib/TrustClient.sol";
import "lib/Util.sol";
import "lib/Relay.sol";
import "./DVIP.sol";

/**
 * @title DCAssetBackend Contract
 *
 * @author Ray Pulver, ray@decentralizedcapital.com
 */
contract DCAssetBackend is Owned, Precision, StateTransferrable, TrustClient, Util {

  bytes32 public standard = 'Token 0.1';
  bytes32 public name;
  bytes32 public symbol;

  bool public allowTransactions;

  event Approval(address indexed from, address indexed spender, uint256 amount);

  mapping (address => uint256) public balanceOf;
  mapping (address => mapping (address => uint256)) public allowance;

  event Transfer(address indexed from, address indexed to, uint256 value);

  uint256 public totalSupply;

  address public hotWalletAddress;
  address public assetAddress;
  address public oversightAddress;
  address public membershipAddress;

  mapping (address => bool) public frozenAccount;

  mapping (address => address[]) public allowanceIndex;
  mapping (address => mapping (address => bool)) public allowanceActive;
  address[] public accountIndex;
  mapping (address => bool) public accountActive;

  bool public isActive;
  uint256 public treasuryBalance;

  mapping (address => uint256) public feeCharge;
  address[] public feeChargeIndex;
  mapping (address => bool) feeActive;

  event FrozenFunds(address target, bool frozen);
  event PrecisionSet(address indexed from, uint8 precision);
  event TransactionsShutDown(address indexed from);
  event FeeSetup(address indexed from, address indexed target, uint256 amount);


  /**
   * Constructor.
   *
   * @param tokenName Name of the Token
   * @param tokenSymbol The Token Symbol
   */
  function DCAssetBackend(bytes32 tokenSymbol, bytes32 tokenName) {
    isActive = true;
    name = tokenName;
    symbol = tokenSymbol;
    decimals = 6;
    allowTransactions = true;
  }

  /* ---------------  modifiers  --------------*/

  /**
   * Makes sure a method is only called by an overseer.
   */
  modifier onlyOverseer {
    assert(msg.sender == oversightAddress);
    _
  }

  /**
   * Make sure only the front end Asset can call the transfer methods
   */
   modifier onlyAsset {
    assert(msg.sender == assetAddress);
    _
   }

  /* ---------------  setter methods, only for the unlocked state --------------*/


  /**
   * Sets the hot wallet contract address
   *
   * @param addr Address of the Hotwallet
   */
  function setHotWallet(address addr) onlyOwnerUnlocked setter {
    hotWalletAddress = addr;
  }

  /**
    * Sets the token facade contract address
    *
    * @param addr Address of the front-end Asset
    */
  function setAsset(address addr) onlyOwnerUnlocked setter {
    assetAddress = addr;
  }

  /**
   * Sets the membership contract address
   *
   * @param addr Address of the membership contract
   */
  function setMembership(address addr) onlyOwnerUnlocked setter {
    membershipAddress = addr;
  }

  /**
   * Sets the oversight address (not the contract).
   *
   * @param addr The oversight contract address.
   */
  function setOversight(address addr) onlyOwnerUnlocked setter {
    oversightAddress = addr;
  }

  /**
   * Sets the total supply
   *
   * @param total Total supply of the asset.
   */
  function setTotalSupply(uint256 total) onlyOwnerUnlocked setter {
    totalSupply = total;
  }

  /**
   * Set the Token Standard the contract applies to.
   *
   * @param std the Standard.
   */
  function setStandard(bytes32 std) onlyOwnerUnlocked setter {
    standard = std;
  }

  /**
   * Sets the name of the contraxt
   *
   * @param _name the name.
   */
  function setName(bytes32 _name) onlyOwnerUnlocked setter {
    name = _name;
  }

  /**
   * Sets the symbol
   *
   * @param sym The Symbol
   */
  function setSymbol(bytes32 sym) onlyOwnerUnlocked setter {
    symbol = sym;
  }

  /**
   * Sets the precision
   *
   * @param precision Amount of decimals
   */
  function setPrecisionDirect(uint8 precision) onlyOwnerUnlocked {
    decimals = precision;
    PrecisionSet(msg.sender, precision);
  }

  /**
   * Sets the balance of a certain account.
   *
   * @param addr Address of the account
   * @param amount Amount of assets to set on the account
   */
  function setAccountBalance(address addr, uint256 amount) onlyOwnerUnlocked {
    balanceOf[addr] = amount;
    activateAccount(addr);
  }

  /**
   * Sets an allowance from a specific account to a specific account.
   *
   * @param from From-part of the allowance
   * @param to To-part of the allowance
   * @param amount Amount of the allowance
   */
  function setAccountAllowance(address from, address to, uint256 amount) onlyOwnerUnlocked {
    allowance[from][to] = amount;
    activateAllowanceRecord(from, to);
  }

  /**
   * Sets the treasure balance to a certain account.
   *
   * @param amount Amount of assets to pre-set in the treasury
   */
  function setTreasuryBalance(uint256 amount) onlyOwnerUnlocked {
    treasuryBalance = amount;
  }

  /**
   * Sets a certain account on frozen/unfrozen
   *
   * @param addr Account that will be frozen/unfrozen
   * @param frozen Boolean to freeze or unfreeze
   */
  function setAccountFrozenStatus(address addr, bool frozen) onlyOwnerUnlocked {
    activateAccount(addr);
    frozenAccount[addr] = frozen;
  }

  /* ---------------  main token methods  --------------*/


  /**
   * @notice Transfer `_amount` from `_caller` to `_to`.
   *
   * @param _caller Origin address
   * @param _to Address that will receive.
   * @param _amount Amount to be transferred.
   */
  function transfer(address _caller, address _to, uint256 _amount) onlyAsset returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[_caller]);
    assert(balanceOf[_caller] >= _amount);
    assert(balanceOf[_to] + _amount >= balanceOf[_to]);
    activateAccount(_caller);
    activateAccount(_to);
    balanceOf[_caller] -= _amount;
    if (_to == address(this)) treasuryBalance += _amount;
    else {
        uint256 fee = feeFor(_caller, _to, _amount);
        balanceOf[_to] += _amount - fee;
        treasuryBalance += fee;
    }
    Transfer(_caller, _to, _amount);
    return true;
  }

  /**
   * @notice Transfer `_amount` from `_from` to `_to`, invoked by `_caller`.
   *
   * @param _caller Invoker of the call (owner of the allowance)
   * @param _from Origin address
   * @param _to Address that will receive
   * @param _amount Amount to be transferred.
   * @return result of the method call
   */
  function transferFrom(address _caller, address _from, address _to, uint256 _amount) onlyAsset returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[_caller]);
    assert(!frozenAccount[_from]);
    assert(balanceOf[_from] >= _amount);
    assert(balanceOf[_to] + _amount >= balanceOf[_to]);
    assert(_amount <= allowance[_from][_caller]);
    balanceOf[_from] -= _amount;
    uint256 fee = feeFor(_from, _to, _amount);
    balanceOf[_to] += _amount - fee;
    treasuryBalance += fee;
    allowance[_from][_caller] -= _amount;
    activateAccount(_from);
    activateAccount(_to);
    activateAccount(_caller);
    Transfer(_from, _to, _amount);
    return true;
  }

  /**
   * @notice Approve Approves spender `_spender` to transfer `_amount` from `_caller`
   *
   * @param _caller Address that grants the allowance
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @param _extraData Consequential contract to be executed by spender in same transcation.
   * @return result of the method call
   */
  function approveAndCall(address _caller, address _spender, uint256 _amount, bytes _extraData) onlyAsset returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[_caller]);
    allowance[_caller][_spender] = _amount;
    activateAccount(_caller);
    activateAccount(_spender);
    activateAllowanceRecord(_caller, _spender);
    TokenRecipient spender = TokenRecipient(_spender);
    assert(Relay(assetAddress).relayReceiveApproval(_caller, _spender, _amount, _extraData));
    Approval(_caller, _spender, _amount);
    return true;
  }

  /**
   * @notice Approve Approves spender `_spender` to transfer `_amount` from `_caller`
   *
   * @param _caller Address that grants the allowance
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @return result of the method call
   */
  function approve(address _caller, address _spender, uint256 _amount) onlyAsset returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[_caller]);
    allowance[_caller][_spender] = _amount;
    activateAccount(_caller);
    activateAccount(_spender);
    activateAllowanceRecord(_caller, _spender);
    Approval(_caller, _spender, _amount);
    return true;
  }

  /* ---------------  multisig admin methods  --------------*/


  /**
   * @notice Mints `mintedAmount` new tokens to the hotwallet `hotWalletAddress`.
   *
   * @param mintedAmount Amount of new tokens to be minted.
   */
  function mint(uint256 mintedAmount) multisig(sha3(msg.data)) {
    activateAccount(hotWalletAddress);
    balanceOf[hotWalletAddress] += mintedAmount;
    totalSupply += mintedAmount;
  }

  /**
   * @notice Destroys `destroyAmount` new tokens from the hotwallet `hotWalletAddress`
   *
   * @param destroyAmount Amount of new tokens to be minted.
   */
  function destroyTokens(uint256 destroyAmount) multisig(sha3(msg.data)) {
    assert(balanceOf[hotWalletAddress] >= destroyAmount);
    activateAccount(hotWalletAddress);
    balanceOf[hotWalletAddress] -= destroyAmount;
    totalSupply -= destroyAmount;
  }

  /**
   * @notice Transfers `amount` from the treasury to `to`
   *
   * @param to Address to transfer to
   * @param amount Amount to transfer from treasury
   */
  function transferFromTreasury(address to, uint256 amount) multisig(sha3(msg.data)) {
    assert(treasuryBalance >= amount);
    treasuryBalance -= amount;
    balanceOf[to] += amount;
    activateAccount(to);
  }

  /* ---------------  multisig emergency methods --------------*/

  /**
   * @notice Sets allow transactions to `allow`
   *
   * @param allow Allow or disallow transactions
   */
  function voteAllowTransactions(bool allow) multisig(sha3(msg.data)) {
    if (allow == allowTransactions) throw;
    allowTransactions = allow;
  }

  /**
   * @notice Destructs the contract and sends remaining `this.balance` Ether to `beneficiary`
   *
   * @param beneficiary Beneficiary of remaining Ether on contract
   */
  function voteSuicide(address beneficiary) multisig(sha3(msg.data)) {
    selfdestruct(beneficiary);
  }

  /**
   * @notice Sets frozen to `freeze` for account `target`
   *
   * @param addr Address to be frozen/unfrozen
   * @param freeze Freeze/unfreeze account
   */
  function freezeAccount(address addr, bool freeze) multisig(sha3(msg.data)) {
    frozenAccount[addr] = freeze;
    activateAccount(addr);
  }

  /**
   * @notice Seizes `seizeAmount` of tokens from `address` and transfers it to hotwallet
   *
   * @param addr Adress to seize tokens from
   * @param amount Amount of tokens to seize
   */
  function seizeTokens(address addr, uint256 amount) multisig(sha3(msg.data)) {
    assert(balanceOf[addr] >= amount);
    assert(frozenAccount[addr]);
    activateAccount(addr);
    balanceOf[addr] -= amount;
    balanceOf[hotWalletAddress] += amount;
  }

  /* ---------------  overseer methods for emergency --------------*/

  /**
   * @notice Shuts down all transaction and approval options on the asset contract
   */
  function shutdownTransactions() onlyOverseer {
    allowTransactions = false;
    TransactionsShutDown(msg.sender);
  }

  /* ---------------  helper methods for siphoning --------------*/

  function extractAccountAllowanceRecordLength(address addr) returns (uint256 len) {
    return allowanceIndex[addr].length;
  }

  function extractAccountLength() returns (uint256 length) {
    return accountIndex.length;
  }


  /* ---------------  private methods --------------*/

  function activateAccount(address addr) internal {
    if (!accountActive[addr]) {
      accountActive[addr] = true;
      accountIndex.push(addr);
    }
  }

  function activateAllowanceRecord(address from, address to) internal {
    if (!allowanceActive[from][to]) {
      allowanceActive[from][to] = true;
      allowanceIndex[from].push(to);
    }
  }
  function feeFor(address a, address b, uint256 amount) returns (uint256 value) {
    if (membershipAddress == address(0x0)) return 0;
    return DVIP(membershipAddress).feeFor(a, b, amount);
  }
}
