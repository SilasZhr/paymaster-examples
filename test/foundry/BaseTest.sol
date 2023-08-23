pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "6551/interfaces/IERC6551Registry.sol";
import "6551/ERC6551Registry.sol";
import "6551/ERC6551Account.sol";
import "./mocks/MockERC721.sol";

contract BaseTest is Test {
  bool private s_baseTestInitialized;
  address internal constant OWNER = 0x00007e64E1fB0C487F25dd6D3601ff6aF8d32e4e;
  ERC6551Registry public registry;
  address public account;
  ERC6551Account public implementation;
  uint256 public chainId = 100;
  MockERC721 nft = new MockERC721();
  address public tokenAddress = address(nft);
  uint256 public tokenId = 1;
  uint256 public salt = 400;

  function setUp() public virtual {
    // BaseTest.setUp is often called multiple times from tests' setUp due to inheritance.
    if (s_baseTestInitialized) return;
    s_baseTestInitialized = true;

    // Set msg.sender to OWNER until changePrank or stopPrank is called
    vm.startPrank(OWNER);
    vm.chainId(chainId);

    // Deploy ERC6551 registry & account
    registry = new ERC6551Registry();
  }
}
