import "lib/Token.sol";
import "lib/TokenRecipient.sol";
import "lib/StateTransferrable.sol";
import "lib/TrustClient.sol";
import "lib/Util.sol";

/**
 * @title DVIP Contract. DCAsset Membership Token contract.
 *
 * @author Ray Pulver, ray@decentralizedcapital.com
 */
contract DVIP is Token, StateTransferrable, TrustClient, Util {

  uint256 public totalSupply;

  mapping (address => bool) public frozenAccount;

  mapping (address => address[]) public allowanceIndex;
  mapping (address => mapping (address => bool)) public allowanceActive;
  address[] public accountIndex;
  mapping (address => bool) public accountActive;
  address public oversightAddress;
  mapping (address => bool) public authorizedVendors;
  uint256 public expiry;

  uint256 public treasuryBalance;

  bool public isActive;
  mapping (address => uint256) public exportFee;
  address[] public exportFeeIndex;
  mapping (address => bool) exportFeeActive;

  mapping (address => uint256) public importFee;
  address[] public importFeeIndex;
  mapping (address => bool) importFeeActive;

  event FrozenFunds(address target, bool frozen);
  event PrecisionSet(address indexed from, uint8 precision);
  event TransactionsShutDown(address indexed from);
  event FeeSetup(address indexed from, address indexed target, uint256 amount);


  /**
   * Constructor.
   *
   */
  function DVIP() {
    isActive = true;
    treasuryBalance = 0;
    totalSupply = 0;
    name = "DVIP";
    symbol = "DVIP";
    decimals = 6;
    allowTransactions = true;
    expiry = 1514764800; //1 jan 2018
  }


  /* ---------------  modifiers  --------------*/

  /**
   * Makes sure a method is only called by an overseer.
   */
  modifier onlyOverseer {
    assert(msg.sender == oversightAddress);
    _
  }

  /* ---------------  setter methods, only for the unlocked state --------------*/


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

  /**
   * Sets up a import fee for a certain address.
   *
   * @param addr Address that will require fee
   * @param fee Amount of fee
   */
  function setupImportFee(address addr, uint256 fee) onlyOwnerUnlocked {
    importFee[addr] = fee;
    activateImportFeeChargeRecord(addr);
    FeeSetup(msg.sender, addr, fee);
  }
 
  /**
   * Sets up a export fee for a certain address.
   *
   * @param addr Address that will require fee
   * @param fee Amount of fee
   */
  function setupExportFee(address addr, uint256 fee) onlyOwnerUnlocked {
    exportFee[addr] = fee;
    activateExportFeeChargeRecord(addr);
    FeeSetup(msg.sender, addr, fee);
  }

  /* ---------------  main token methods  --------------*/


  /**
   * @notice Transfer `_amount` from `msg.sender.address()` to `_to`.
   *
   * @param _to Address that will receive.
   * @param _amount Amount to be transferred.
   */
  function transfer(address _to, uint256 _amount) returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[msg.sender]);
    assert(balanceOf[msg.sender] >= _amount);
    uint256 pointZeroOne;
    if (!authorizedVendors[msg.sender]) {
      pointZeroOne = pow10(1, decimals - 2);
      assert(balanceOf[msg.sender] >= pointZeroOne);
    }
    assert(balanceOf[_to] + _amount >= balanceOf[_to]);
    activateAccount(msg.sender);
    activateAccount(_to);
    balanceOf[msg.sender] -= _amount;
    if (_to == address(this)) treasuryBalance += _amount;
    else if (!authorizedVendors[msg.sender]) {
      balanceOf[_to] += _amount - pointZeroOne;
      treasuryBalance += pointZeroOne;
    } else {
      balanceOf[_to] += _amount;
    }
    Transfer(msg.sender, _to, _amount);
    return true;
  }

  /**
   * @notice Transfer `_amount` from `_from` to `_to`.
   *
   * @param _from Origin address
   * @param _to Address that will receive
   * @param _amount Amount to be transferred.
   * @return result of the method call
   */
  function transferFrom(address _from, address _to, uint256 _amount) returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[msg.sender]);
    assert(!frozenAccount[_from]);
    assert(balanceOf[_from] >= _amount);
    assert(balanceOf[_to] + _amount >= balanceOf[_to]);
    uint256 pointZeroOne;
    if (!authorizedVendors[_from]) {
      pointZeroOne = pow10(1, decimals - 2);
      assert(balanceOf[_from] >= pointZeroOne);
    }
    assert(_amount <= allowance[_from][msg.sender]);
    balanceOf[_from] -= _amount;
    if (!authorizedVendors[_from]) {
      balanceOf[_to] += _amount - pointZeroOne;
      treasuryBalance += pointZeroOne;
    } else {
      balanceOf[_to] += _amount;
    }
    allowance[_from][msg.sender] -= _amount;
    activateAccount(_from);
    activateAccount(_to);
    activateAccount(msg.sender);
    Transfer(_from, _to, _amount);
    return true;
  }

  /**
   * @notice Approve spender `_spender` to transfer `_amount` from `msg.sender.address()`
   *
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @param _extraData Consequential contract to be executed by spender in same transcation.
   * @return result of the method call
   */
  function approveAndCall(address _spender, uint256 _amount, bytes _extraData) returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[msg.sender]);
    allowance[msg.sender][_spender] = _amount;
    activateAccount(msg.sender);
    activateAccount(_spender);
    activateAllowanceRecord(msg.sender, _spender);
    TokenRecipient spender = TokenRecipient(_spender);
    spender.receiveApproval(msg.sender, _amount, this, _extraData);
    Approval(msg.sender, _spender, _amount);
    return true;
  }

  /**
   * @notice Approve spender `_spender` to transfer `_amount` from `msg.sender.address()`
   *
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @return result of the method call
   */
  function approve(address _spender, uint256 _amount) returns (bool success) {
    assert(allowTransactions);
    assert(!frozenAccount[msg.sender]);
    allowance[msg.sender][_spender] = _amount;
    activateAccount(msg.sender);
    activateAccount(_spender);
    activateAllowanceRecord(msg.sender, _spender);
    Approval(msg.sender, _spender, _amount);
    return true;
  }

  /* ---------------  multisig admin methods  --------------*/



  /**
   * @notice Sets the expiry time in milliseconds since 1970.
   *
   * @param ts milliseconds since 1970.
   *
   */
  function setExpiry(uint256 ts) multisig(sha3(msg.data)) {
    expiry = ts;
  }

  function setAuthorizedVendor(address addr, bool authorized) multisig(sha3(msg.data)) {
    authorizedVendors[addr] = authorized;
  }

  /**
   * @notice Mints `mintedAmount` new tokens to the hotwallet `hotWalletAddress`.
   *
   * @param mintedAmount Amount of new tokens to be minted.
   */
  function mint(uint256 mintedAmount) multisig(sha3(msg.data)) {
    treasuryBalance += mintedAmount;
    totalSupply += mintedAmount;
  }

  /**
   * @notice Destroys `destroyAmount` new tokens from the hotwallet `hotWalletAddress`
   *
   * @param destroyAmount Amount of new tokens to be minted.
   */
  function destroyTokens(uint256 destroyAmount) multisig(sha3(msg.data)) {
    assert(treasuryBalance >= destroyAmount);
    treasuryBalance -= destroyAmount;
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

  /* ---------------  fee setting administration methods  --------------*/

  /**
   * @notice Sets an export fee of `fee` on address `addr`
   *
   * @param addr Address for which the fee is valid
   * @param addr fee Fee
   *
   */
  function setExportFee(address addr, uint256 fee) multisig(sha3(msg.data)) {
    uint256 max = 1;
    max = pow10(1, decimals);
    assert(fee <= max);
    exportFee[addr] = fee;
    activateExportFeeChargeRecord(addr);
  }

  /* ---------------  multisig emergency methods --------------*/

  /**
   * @notice Sets allow transactions to `allow`
   *
   * @param allow Allow or disallow transactions
   */
  function voteAllowTransactions(bool allow) multisig(sha3(msg.data)) {
    assert(allow != allowTransactions);
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
    treasuryBalance += amount;
  }

  /* --------------- fee calculation method ---------------- */


  /**
   * @notice 'Returns the fee for a transfer from `from` to `to` on an amount `amount`.
   *
   * Fee's consist of a possible
   *    - import fee on transfers to an address
   *    - export fee on transfers from an address
   * DVIP ownership on an address
   *    - reduces fee on a transfer from this address to an import fee-ed address
   *    - reduces the fee on a transfer to this address from an export fee-ed address
   * DVIP discount does not work for addresses that have an import fee or export fee set up against them.
   *
   * DVIP discount goes up to 100%
   *
   * @param from From address
   * @param to To address
   * @param amount Amount for which fee needs to be calculated.
   *
   */
  function feeFor(address from, address to, uint256 amount) constant external returns (uint256 value) {
    uint256 fee = exportFee[from];
    if (fee == 0) return 0;
    uint256 amountHeld;
    bool discounted = true;
    uint256 oneDVIPUnit;
    if (exportFee[from] == 0 && balanceOf[from] != 0 && now < expiry) {
      amountHeld = balanceOf[from];
    } else discounted = false;
    if (discounted) {
      oneDVIPUnit = pow10(1, decimals);
      if (amountHeld > oneDVIPUnit) amountHeld = oneDVIPUnit;
      uint256 remaining = oneDVIPUnit - amountHeld;
      return div10(amount*fee*remaining, decimals*2);
    }
    return div10(amount*fee, decimals);
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

  function extractAccountAllowanceRecordLength(address addr) constant returns (uint256 len) {
    return allowanceIndex[addr].length;
  }

  function extractAccountLength() constant returns (uint256 length) {
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

  function activateExportFeeChargeRecord(address addr) internal {
    if (!exportFeeActive[addr]) {
      exportFeeActive[addr] = true;
      exportFeeIndex.push(addr);
    }
  }

  function activateImportFeeChargeRecord(address addr) internal {
    if (!importFeeActive[addr]) {
      importFeeActive[addr] = true;
      importFeeIndex.push(addr);
    }
  }
  function extractImportFeeChargeLength() returns (uint256 length) {
    return importFeeIndex.length;
  }

  function extractExportFeeChargeLength() returns (uint256 length) {
    return exportFeeIndex.length;
  }
}
