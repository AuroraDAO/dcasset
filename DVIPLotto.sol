import "lib/TrustClient.sol";
import "./DVIP.sol";

contract DVIPLotto is TrustClient {
  address[] public entries;
  uint256 public length;
  struct WinningEvent {
    uint256 seed;
    address[] awarded;
    mapping (uint256 => bool) used;
  }
  mapping (uint256 => WinningEvent) public resolutions;
  uint256 public price;
  address public dvipAddress;
  event Winner(address indexed winner, uint256 indexed number);
  event Entry(address indexed winner, uint256 indexed count);
  function setDVIP(address addr) onlyOwnerUnlocked returns (bool success) {
    dvipAddress = addr;
    PropertySet(msg.sender);
    return true;
  }
  function setPrice(uint256 _price) onlyOwnerUnlocked returns (bool success) {
    price = _price;
    PropertySet(msg.sender);
    return true;
  }
  function resolve(uint256 tokens) multisig(sha3(msg.data)) {
    assert(DVIP(dvipAddress).balanceOf(this) >= tokens);
    resolutions[block.number].seed = uint256(block.blockhash(block.number));
    for (uint256 i = 0; i < tokens; i++) { 
      uint256 number;
      bool chosen = false;
      while (!chosen) {
        number = uint256(sha3(resolutions[block.number].seed)) % length;
        if (!resolutions[block.number].used[number]) {
          resolutions[block.number].used[number] = true;
          chosen = true;
        } else {
          resolutions[block.number].seed++;
        }
      }
      address winner = entries[number];
      resolutions[block.number].seed++;
      resolutions[block.number].awarded.push(winner);
      if (!DVIP(dvipAddress).transfer(winner, 1)) throw;
      Winner(winner, number);
    }
    length = 0;
  }
  function suicide(address beneficiary) multisig(sha3(msg.data)) {
    selfdestruct(beneficiary);
  }
  function withdraw(address beneficiary, uint256 amount) multisig(sha3(msg.data)) {
    if (!beneficiary.send(amount)) throw;
  }
  function () {
    assert(msg.value >= price);
    uint256 purchase = msg.value / price;
    uint256 refund = msg.value % price;
    if (refund != 0 && !msg.sender.send(refund)) throw;
    Entry(msg.sender, purchase);
    for (uint256 i = 0; i < purchase; i++) {
      if (entries.length <= length) entries.push(msg.sender);
      else entries[length] = msg.sender;
      length++;
    }
  }
}
