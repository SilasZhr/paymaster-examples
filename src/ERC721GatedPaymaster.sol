// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "aa/core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * A sample paymaster that uses 721 NFT as gate to decide whether to pay for the UserOp.
 */
contract ERC721GatedPaymaster is BasePaymaster {
  using ECDSA for bytes32;
  using UserOperationLib for UserOperation;

  IERC721 public immutable tokenContract;

  constructor(IEntryPoint _entryPoint, address _tokenContract) BasePaymaster(_entryPoint) {
    tokenContract = IERC721(_tokenContract);
  }

  mapping(address => uint256) public senderNonce;

  /**
   * verify our external signer signed this request.
   * the "paymasterAndData" is expected to be the paymaster and a signature over the entire request params
   */
  function _validatePaymasterUserOp(
    UserOperation calldata userOp,
    bytes32 /*userOpHash*/,
    uint256 requiredPreFund
  ) internal override returns (bytes memory context, uint256 validationData) {
    (requiredPreFund); // not used

    bool holder = tokenContract.balanceOf(userOp.sender) > 0;
    // require(tokenContract.balanceOf(userOp.sender) > 0, "ERC721GatedPaymaster: User does not own the required NFT");
    senderNonce[userOp.getSender()]++;
    if (!holder) {
      return ("", _packValidationData(true, 0xFFFFFFFFFFFF, 0));
    }

    return ("", _packValidationData(false, 0xFFFFFFFFFFFF, 0));
  }
}
