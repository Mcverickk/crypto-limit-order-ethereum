// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import "../src/Swap.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import 'lib/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol';
import 'lib/v3-periphery/contracts/libraries/TransferHelper.sol';

contract SwapTest is Test {
    Swap public swap;
    address public swapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public UNI = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;
    address public USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    address public addressWithPOL = 0xf9149e446ba99B5583604fC8312707eB1065FcD4;
    address public addressWithWMATIC = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address public addressWithUNI = 0xB33bD56d4192E8E4e6a02e93Eabc732165199346;
    address public addressWithUSDC = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;

    address public myAddress = 0xD43ABDA398A684b25595b5460A8040005d69d32d;

    uint104 public blockNumber = 65050080;


    function setUp() public {
        vm.createSelectFork("mainnet", blockNumber);
        swap = new Swap(ISwapRouter02(swapRouter), WMATIC);
    }

    function testFork() view public {
        assertEq(block.number, blockNumber);
    }

    function testDeposit() public {
        vm.prank(addressWithPOL);
        swap.deposit{value: 1000}();
        assertEq(swap.coinBalance(addressWithPOL), 1000);
        vm.prank(myAddress);
        swap.deposit{value: 2000}();
        assertEq(swap.coinBalance(myAddress), 2000);
    }

    function testWithdraw() public {
        vm.startPrank(addressWithPOL);
        swap.deposit{value: 1000}();
        swap.withdraw(500);
        assertEq(swap.coinBalance(addressWithPOL), 500);
    }

    function testWithdrawAll() public {
        vm.startPrank(addressWithPOL);
        swap.deposit{value: 1000}();
        swap.deposit{value: 2000}();
        swap.deposit{value: 500}();
        assertEq(swap.coinBalance(addressWithPOL), 3500);
        swap.withdrawAll();
        assertEq(swap.coinBalance(addressWithPOL), 0);
    }

    function testDirectEthSendToSwap() public {
        vm.startPrank(addressWithPOL);
        uint256 balance = addressWithPOL.balance;
        payable(address(swap)).call{value: 10 ether}("");
        uint256 balanceAfter = addressWithPOL.balance;
        assertEq(balanceAfter, balance - 10 ether);
    }

    function testSwapCoinToToken() public {
        vm.prank(addressWithPOL);
        swap.deposit{value: 1 ether}();

        IERC20 token = IERC20(UNI);

        vm.prank(myAddress);
        uint amountOut = swap.swapCoinToToken(UNI, 3000, 1 ether, 0.0477468 ether, addressWithPOL);

        assertEq(token.balanceOf(addressWithPOL), amountOut);
    }

    function testSwapCoinToTokenWithMoreDeposit() public {
        vm.prank(addressWithPOL);
        swap.deposit{value: 2 ether}();

        IERC20 usdc = IERC20(USDC);

        vm.prank(myAddress);
        uint amountOut = swap.swapCoinToToken(USDC, 3000, 1 ether, 693900, addressWithPOL);

        assertEq(usdc.balanceOf(addressWithPOL), amountOut);
    }

    function testFailSwapCoinToTokenWithLessDeposit() public {
        vm.prank(addressWithPOL);
        swap.deposit{value: 0.5 ether}();

        IERC20 usdc = IERC20(USDC);

        vm.prank(myAddress);
        uint amountOut = swap.swapCoinToToken(USDC, 3000, 1 ether, 693900, addressWithPOL);

        assertEq(usdc.balanceOf(addressWithPOL), amountOut);
    }

    function testSwapTokenToCoin() public {
        IERC20 uni = IERC20(UNI);
        vm.prank(addressWithUNI);
        uni.approve(address(swap), 10 ether);

        vm.prank(myAddress);
        uint amountOut = swap.swapTokenToCoin(UNI, 3000, 10 ether, 200 ether, addressWithUNI);
        assertEq(addressWithUNI.balance, amountOut);
    }

    function testSwapTokenToToken() public {
        IERC20 usdc = IERC20(USDC);
        vm.prank(addressWithUSDC);
        usdc.approve(address(swap), 16000000);

        vm.prank(myAddress);
        uint amountOut = swap.swapTokenToToken(USDC, UNI, 3000, 16000000, 1 ether, addressWithUSDC);

        IERC20 uni = IERC20(UNI);
        assertEq(uni.balanceOf(addressWithUSDC), amountOut);
    }
	
}