// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "src/ERC6551GatedPaymaster.sol";
import "account-abstraction/contracts/core/EntryPoint.sol";
import "account-abstraction/contracts/interfaces/UserOperation.sol";
import "account-abstraction/contracts/samples/SimpleAccountFactory.sol";
import "forge-std/Test.sol";
import "./mocks/MockERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./BytesLib.sol";
import "./BaseTest.sol";

using ECDSA for bytes32;

contract ERC6551GatedPaymasterTest is BaseTest {
  EntryPoint entryPoint;
  SimpleAccountFactory accountFactory;
  ERC6551GatedPaymaster paymaster;
  address paymasterOperator;
  address payable beneficiary;
  address user;
  uint256 userKey;

  function setUp() public override {
    BaseTest.setUp();
    paymasterOperator = makeAddr("paymasterOperator");
    vm.deal(paymasterOperator, 1000e18);
    changePrank(paymasterOperator);
    beneficiary = payable(makeAddr("beneficiary"));
    (user, userKey) = makeAddrAndKey("user");
    nft.mint(user, 1);
    nft.mint(user, 999);
    entryPoint = new EntryPoint();
    implementation = new ERC6551Account(address(entryPoint));
    account = ERC6551Registry(registry).createAccount(
      address(implementation),
      chainId,
      tokenAddress,
      tokenId,
      salt,
      ""
    );
    accountFactory = new SimpleAccountFactory(entryPoint);
    paymaster = new ERC6551GatedPaymaster(entryPoint, tokenAddress, address(registry));

    entryPoint.depositTo{value: 100e18}(address(paymaster));
    paymaster.addStake{value: 100e18}(1);
    vm.stopPrank();
    vm.warp(1680509051);
  }

  function testDeploy() external {
    vm.startPrank(paymasterOperator);
    ERC6551GatedPaymaster testArtifact = new ERC6551GatedPaymaster(entryPoint, tokenAddress, address(registry));
    vm.stopPrank();
    assertEq(address(testArtifact.tokenContract()), tokenAddress);
    assertEq(address(testArtifact.entryPoint()), address(entryPoint));
    assertEq(address(testArtifact.owner()), paymasterOperator);
  }

  function testOwnershipTransfer() external {
    vm.startPrank(paymasterOperator);
    assertEq(paymaster.owner(), paymasterOperator);
    paymaster.transferOwnership(beneficiary);
    assertEq(paymaster.owner(), beneficiary);
    vm.stopPrank();
  }

  function signUserOp(UserOperation memory op, uint256 _key) public returns (bytes memory signature) {
    bytes32 hash = entryPoint.getUserOpHash(op);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
    signature = abi.encodePacked(r, s, v);
  }

  // sanity check for everything works without paymaster
  function testCall() external {
    vm.deal(address(account), 1e18);
    (UserOperation memory op, uint256 prefund) = fillUserOp(
      SimpleAccount(payable(account)),
      userKey,
      address(0),
      0,
      ""
    );
    op.signature = signUserOp(op, userKey);
    UserOperation[] memory ops = new UserOperation[](1);
    ops[0] = op;
    entryPoint.handleOps(ops, beneficiary);
  }

  function testPaymaster() external {
    vm.deal(address(account), 1e18);
    (UserOperation memory op, uint256 prefund) = fillUserOp(
      SimpleAccount(payable(account)),
      userKey,
      address(0),
      0,
      ""
    );
    op.paymasterAndData = abi.encodePacked(address(paymaster));
    op.signature = signUserOp(op, userKey);
    UserOperation[] memory ops = new UserOperation[](1);
    ops[0] = op;
    entryPoint.handleOps(ops, beneficiary);
  }

  function testPaymasterFailed() external {
    (address testUser, uint256 testUserKey) = makeAddrAndKey("testUser");
    vm.prank(testUser);
    address testAccount = ERC6551Registry(registry).createAccount(
      address(implementation),
      chainId,
      address(nft),
      999,
      salt,
      ""
    );
    vm.deal(address(testAccount), 1e18);
    (UserOperation memory op, uint256 prefund) = fillUserOp(
      SimpleAccount(payable(testAccount)),
      userKey,
      address(0),
      0,
      ""
    );
    op.paymasterAndData = abi.encodePacked(address(paymaster));
    op.signature = signUserOp(op, testUserKey);
    UserOperation[] memory ops = new UserOperation[](1);
    ops[0] = op;
    vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA24 signature error"));
    entryPoint.handleOps(ops, beneficiary);
  }

  function fillUserOp(
    SimpleAccount _sender,
    uint256 _key,
    address _to,
    uint256 _value,
    bytes memory _data
  ) public returns (UserOperation memory op, uint256 prefund) {
    op.sender = address(_sender);
    op.nonce = entryPoint.getNonce(address(_sender), 0);
    op.callData = abi.encodeWithSelector(SimpleAccount.execute.selector, _to, _value, _data);
    op.callGasLimit = 50000;
    op.verificationGasLimit = 80000;
    op.preVerificationGas = 50000;
    op.maxFeePerGas = 1000000000;
    op.maxPriorityFeePerGas = 100;
    op.signature = signUserOp(op, _key);
    (op, prefund) = simulateVerificationGas(entryPoint, op);
    op.callGasLimit = simulateCallGas(entryPoint, op);
    //op.signature = signUserOp(op, _name);
  }

  function simulateVerificationGas(
    EntryPoint _entrypoint,
    UserOperation memory op
  ) public returns (UserOperation memory, uint256 preFund) {
    (bool success, bytes memory ret) = address(_entrypoint).call(
      abi.encodeWithSelector(EntryPoint.simulateValidation.selector, op)
    );
    require(!success);
    bytes memory data = BytesLib.slice(ret, 4, ret.length - 4);
    (IEntryPoint.ReturnInfo memory retInfo, , , ) = abi.decode(
      data,
      (IEntryPoint.ReturnInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo)
    );
    op.preVerificationGas = retInfo.preOpGas;
    op.verificationGasLimit = retInfo.preOpGas;
    op.maxFeePerGas = (retInfo.prefund * 11) / (retInfo.preOpGas * 10);
    op.maxPriorityFeePerGas = 1;
    return (op, retInfo.prefund);
  }

  function simulateCallGas(EntryPoint _entrypoint, UserOperation memory op) internal returns (uint256) {
    try this.calcGas(_entrypoint, op.sender, op.callData) {
      revert("Should have failed");
    } catch Error(string memory reason) {
      uint256 gas = abi.decode(bytes(reason), (uint256));
      return (gas * 11) / 10;
    } catch {
      revert("Should have failed");
    }
  }

  // not used internally
  function calcGas(EntryPoint _entrypoint, address _to, bytes memory _data) external {
    vm.startPrank(address(_entrypoint));
    uint256 g = gasleft();
    (bool success, ) = _to.call(_data);
    require(success);
    g = g - gasleft();
    bytes memory r = abi.encode(g);
    vm.stopPrank();
    require(false, string(r));
  }
}
