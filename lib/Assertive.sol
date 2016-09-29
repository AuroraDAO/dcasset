contract Assertive {
  function assert(bool assertion) {
    if (!assertion) throw;
  }
}
