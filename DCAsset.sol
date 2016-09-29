import "lib/TokenBase.sol";
import "lib/TokenRecipient.sol";
import "lib/StateTransferrable.sol";
import "lib/TrustClient.sol";
import "lib/Relay.sol";
import "./DCAssetBackend.sol";


/**
 * @title DCAssetFacade, Facade for the underlying back-end dcasset token contract. Allow to be updated later.
 *
 * @author P.S.D. Reitsma, peter@decentralizedcapital.com
 *
 */
contract DCAsset is TokenBase, StateTransferrable, TrustClient, Relay {

   address public backendContract;

   /**
    * Constructor
    *
    *
    */
   function DCAsset(address _backendContract) {
     backendContract = _backendContract;
   }

   function standard() constant returns (bytes32 std) {
     return DCAssetBackend(backendContract).standard();
   }

   function name() constant returns (bytes32 nm) {
     return DCAssetBackend(backendContract).name();
   }

   function symbol() constant returns (bytes32 sym) {
     return DCAssetBackend(backendContract).symbol();
   }

   function decimals() constant returns (uint8 precision) {
     return DCAssetBackend(backendContract).decimals();
   }
  
   function allowance(address from, address to) constant returns (uint256 res) {
     return DCAssetBackend(backendContract).allowance(from, to);
   }


   /* ---------------  multisig admin methods  --------------*/


   /**
    * @notice Sets the backend contract to `_backendContract`. Can only be switched by multisig.
    *
    * @param _backendContract Address of the underlying token contract.
    */
   function setBackend(address _backendContract) multisig(sha3(msg.data)) {
     backendContract = _backendContract;
   }

   /* ---------------  main token methods  --------------*/

   /**
    * @notice Returns the balance of `_address`.
    *
    * @param _address The address of the balance.
    */
   function balanceOf(address _address) constant returns (uint256 balance) {
      return DCAssetBackend(backendContract).balanceOf(_address);
   }

   /**
    * @notice Returns the total supply of the token
    *
    */
   function totalSupply() constant returns (uint256 balance) {
      return DCAssetBackend(backendContract).totalSupply();
   }

  /**
   * @notice Transfer `_amount` to `_to`.
   *
   * @param _to Address that will receive.
   * @param _amount Amount to be transferred.
   */
   function transfer(address _to, uint256 _amount) returns (bool success)  {
      if (!DCAssetBackend(backendContract).transfer(msg.sender, _to, _amount)) throw;
      Transfer(msg.sender, _to, _amount);
      return true;
   }

  /**
   * @notice Approve Approves spender `_spender` to transfer `_amount`.
   *
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @param _extraData Consequential contract to be executed by spender in same transcation.
   * @return result of the method call
   */
   function approveAndCall(address _spender, uint256 _amount, bytes _extraData) returns (bool success) {
      if (!DCAssetBackend(backendContract).approveAndCall(msg.sender, _spender, _amount, _extraData)) throw;
      Approval(msg.sender, _spender, _amount);
      return true;
   }

  /**
   * @notice Approve Approves spender `_spender` to transfer `_amount`.
   *
   * @param _spender Address that receives the cheque
   * @param _amount Amount on the cheque
   * @return result of the method call
   */
   function approve(address _spender, uint256 _amount) returns (bool success) {
      if (!DCAssetBackend(backendContract).approve(msg.sender, _spender, _amount)) throw;
      Approval(msg.sender, _spender, _amount);
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
      if (!DCAssetBackend(backendContract).transferFrom(msg.sender, _from, _to, _amount)) throw;
      Transfer(_from, _to, _amount);
      return true;
  }

  /**
   * @notice Returns fee for transferral of `_amount` from `_from` to `_to`.
   *
   * @param _from Origin address
   * @param _to Address that will receive
   * @param _amount Amount to be transferred.
   * @return height of the fee
   */
  function feeFor(address _from, address _to, uint256 _amount) returns (uint256 amount) {
      return DCAssetBackend(backendContract).feeFor(_from, _to, _amount);
  }

  /* ---------------  to be called by backend  --------------*/

  function relayReceiveApproval(address _caller, address _spender, uint256 _amount, bytes _extraData) returns (bool success) {
     assert(msg.sender == backendContract);
     TokenRecipient spender = TokenRecipient(_spender);
     spender.receiveApproval(_caller, _amount, this, _extraData);
     return true;
  }

}
