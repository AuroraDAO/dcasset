import "lib/TrustClient.sol";
import "lib/Math.sol";
import "./DVIP.sol";

contract MembershipVendor is TrustClient, Math {
  event MembershipPurchase(address indexed from, uint256 indexed amount, uint256 indexed price);
  event PropertySet(address indexed from, bytes32 indexed sig, bytes32 indexed args);
  address public dvipAddress;
  uint256 public price;
  function withdraw(address addr, uint256 amt) multisig(sha3(msg.data)) returns (bool success) {
    if (!addr.send(amt)) throw;
    return true;
  }
  function setDVIP(address addr) onlyOwner returns (bool success) {
    dvipAddress = addr;
    PropertySet(msg.sender, msg.sig, bytes32(addr));
    return true;
  }
  function setPrice(uint256 _price) onlyOwner returns (bool success) {
    price = _price;
    PropertySet(msg.sender, msg.sig, bytes32(_price));
    return true;
  }
  function () {
    if (msg.value < price) throw;
    uint256 qty = msg.value / price;
    uint256 val = safeMul(price, qty);
    if (!DVIP(dvipAddress).transfer(msg.sender, qty)) throw;
    if (msg.value > val && !msg.sender.send(safeSub(msg.value, val))) throw;
  }
}
