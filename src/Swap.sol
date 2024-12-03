//SPDX-Licence-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import 'lib/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol';
import 'lib/v3-periphery/contracts/libraries/TransferHelper.sol';


abstract contract WCoinInterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
    function balanceOf(address account) external virtual returns (uint256);
}

abstract contract ERC20Interface {
    function allowance(address owner, address spender) external virtual view returns (uint256);
}

contract Swap {
    ISwapRouter02 public uniswapRouter;
    WCoinInterface WCoin;
    ERC20Interface Token;
    mapping(address => uint256) public coinBalance;

    address public immutable WETH;

    constructor(ISwapRouter02 _swapRouter, address _WETH) {
        uniswapRouter = _swapRouter;
        WETH = _WETH;
        WCoin = WCoinInterface(_WETH);
    }

    function deposit() public payable {
        coinBalance[msg.sender] += msg.value;
    }

    function withdraw(uint amount) public {
        require(coinBalance[msg.sender] >= amount, "Not enough balance");
        coinBalance[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function withdrawAll() public {
        uint amount = coinBalance[msg.sender];
        coinBalance[msg.sender] = 0;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function swapTokenToToken(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address userAddress
    ) external returns(uint256) {
        Token = ERC20Interface(tokenIn);
        require(Token.allowance(userAddress, address(this)) >= amountIn, "Not enough token allowance");

        TransferHelper.safeTransferFrom(tokenIn, userAddress, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountIn);

        return _swapExactInputSingle(tokenIn, tokenOut, fee, amountIn, amountOutMinimum, userAddress);
    }

    function swapTokenToCoin(
        address tokenIn,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address userAddress
    ) external returns(uint256) {
        Token = ERC20Interface(tokenIn);
        require(Token.allowance(userAddress, address(this)) >= amountIn, "Not enough token allowance");

        TransferHelper.safeTransferFrom(tokenIn, userAddress, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountIn);

        uint256 amountOut = _swapExactInputSingle(tokenIn, WETH, fee, amountIn, amountOutMinimum, address(this));

        WCoin.withdraw(amountOut);
        (bool sent,) = payable(userAddress).call{value: amountOut}("");

        require(sent, "Failed to send Ether");
        return amountOut;
    }

    function swapCoinToToken(
        address tokenOut, 
        uint24 fee, 
        uint256 amountIn, 
        uint256 amountOutMinimum, 
        address userAddress
    ) payable external returns(uint256) {
        require(coinBalance[userAddress] >= amountIn, "Not enough balance deposit");

        WCoin.deposit{value: amountIn}();
        coinBalance[userAddress] -= amountIn;
        TransferHelper.safeApprove(WETH, address(uniswapRouter), amountIn);
        
        uint256 amountOut = _swapExactInputSingle(WETH, tokenOut, fee, amountIn, amountOutMinimum, userAddress);

        return amountOut;
    }



    function _swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address userAddress
    ) internal returns (uint256 amountOut) {

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: userAddress,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        amountOut = uniswapRouter.exactInputSingle(params);

    }

    receive() external payable {
    }

}

