// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "aa/core/BasePaymaster.sol";
import "./utils/ERC6551AccountHelper.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * A sample paymaster that uses 721 NFT as gate to decide whether to pay for the UserOp.
 */
contract ERC6551GatedPaymaster is BasePaymaster {
  using ECDSA for bytes32;
  using UserOperationLib for UserOperation;

  address public immutable tokenContract;
  address public immutable registry;

  constructor(IEntryPoint _entryPoint, address _tokenContract, address _registry) BasePaymaster(_entryPoint) {
    tokenContract = _tokenContract;
    registry = _registry;
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

    bool valid = (userOp.sender == ERC6551AccountHelper.computeAddress(registry, userOp.sender));
    senderNonce[userOp.getSender()]++;
    if (!valid) {
      return ("", _packValidationData(true, 0xFFFFFFFFFFFF, 0));
    }

    return ("", _packValidationData(false, 0xFFFFFFFFFFFF, 0));
  }
}
