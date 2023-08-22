// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Create2.sol";
import "lib/6551/lib/ERC6551BytecodeLib.sol";

library ERC6551AccountHelper {
  function computeAddress(address registry, address account) internal view returns (address) {
    address _implementation = implementation(account);
    (uint256 chainId, address tokenContract, uint256 tokenId) = token(account);
    uint256 _salt = salt(account);
    bytes32 bytecodeHash = keccak256(
      ERC6551BytecodeLib.getCreationCode(_implementation, chainId, tokenContract, tokenId, _salt)
    );

    return Create2.computeAddress(bytes32(_salt), bytecodeHash, registry);
  }

  function token(address account) internal view returns (uint256, address, uint256) {
    bytes memory footer = new bytes(0x60);

    assembly {
      // copy 0x60 bytes from end of footer
      extcodecopy(account, add(footer, 0x20), 0x4d, 0x60)
    }

    return abi.decode(footer, (uint256, address, uint256));
  }

  function salt(address account) internal view returns (uint256) {
    bytes memory footer = new bytes(0x20);

    assembly {
      // copy 0x20 bytes from beginning of footer
      extcodecopy(account, add(footer, 0x20), 0x2d, 0x20)
    }

    return abi.decode(footer, (uint256));
  }

  function implementation(address account) internal view returns (address) {
    bytes memory footer = new bytes(0x20);

    assembly {
      // copy 0x14 bytes from the start of implementation
      extcodecopy(account, add(footer, 0x2C), 0x0A, 0x14)
    }

    return abi.decode(footer, (address));
  }
}
