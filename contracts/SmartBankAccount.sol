//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface cETH {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// @Uniswap/v2-periphery/blob/master/contracts/interfaces
pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

pragma solidity >=0.7.0 <0.9.0;

contract SmartBankAccount {
    uint256 internal contractBalance; // pool ETH in wei
    uint public ethPrice = 0;
    uint public usdTargetPercentage = 40;
    mapping(address => uint256) balances; // user ETH in wei

    address COMPOUND_CETH_ADDRESS = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    cETH ceth = cETH(COMPOUND_CETH_ADDRESS);

    address UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 uniswap = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);

    function addBalance() public payable {
        balances[msg.sender] += msg.value;
        contractBalance += msg.value;
        ceth.mint{value: msg.value}();
    }

    function addBalanceERC20(address erc20Contract) public payable {
        uint256 approvedERC20Amount = addtokens(erc20Contract);
        uint256 ethAmount = swapTokens(erc20Contract, approvedERC20Amount);

        balances[msg.sender] += msg.value;
        contractBalance += msg.value;
        ceth.mint{value: ethAmount}();
    }

    function addtokens(address _erc20Contract) internal returns (uint256) {
        IERC20 erc20 = IERC20(_erc20Contract);

        uint256 approvedERC20Amount = erc20.allowance(
            msg.sender,
            address(this)
        );
        erc20.transferFrom(msg.sender, address(this), approvedERC20Amount);
        erc20.approve(UNISWAP_ROUTER_ADDRESS, approvedERC20Amount);

        return approvedERC20Amount;
    }

    function swapTokens(address _erc20Contract, uint256 _approvedERC20Amount)
        internal
        returns (uint256)
    {
        uint256 amountETHMin = 0; // accept any amount of token

        address[] memory path = new address[](2);
        path[0] = _erc20Contract;
        path[1] = uniswap.WETH(); // check uniswap.exchange

        uint256 before = address(this).balance;
        uniswap.swapExactTokensForETH(
            _approvedERC20Amount,
            amountETHMin,
            path,
            address(this),
            block.timestamp + (24 * 60 * 60)
        );
        uint256 _ethAmount = address(this).balance - before;

        return _ethAmount;
    }

    function withdraw(uint256 withdrawAmount) public payable returns (uint256) {
        require(withdrawAmount <= getUserEth(), "overdrawn");

        balances[msg.sender] -= msg.value;
        contractBalance -= withdrawAmount;

        uint256 cethToRedeem = getTotalEthFromCeth() *
            (withdrawAmount / contractBalance);
        uint256 transferable = ceth.redeem(cethToRedeem);

        (bool sent, ) = payable(msg.sender).call{value: transferable}("");
        require(sent, "Failed to send Ether");

        return transferable;
    }

    // sanity check
    function getAllowanceERC20(address erc20Contract)
        public
        view
        returns (uint256)
    {
        IERC20 erc20 = IERC20(erc20Contract);
        return erc20.allowance(msg.sender, address(this));
    }

    function getbalanceERC20(address erc20Contract)
        public
        view
        returns (uint256)
    {
        IERC20 erc20 = IERC20(erc20Contract);
        return erc20.balanceOf(address(this));
    }

    receive() external payable {}

    // viewing functions
    function getUserEth() public view returns (uint256) {
        return (getTotalEthFromCeth() *
            (balances[msg.sender] / contractBalance))/1e18;
    }

    function getTotalEthFromCeth() public view returns (uint256) {
        return ceth.balanceOf(address(this)) * ceth.exchangeRateStored() / 1e18;
    }

    function getContractBalance() public view returns (uint256) {
        return contractBalance;
    }

    function getExchangeRate() public view returns (uint256) {
        return ceth.exchangeRateStored();
    }
}

// addresses
// Compound on rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
// Compound on ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
// dai on rinkeby = 0xc7ad46e0b8a400bb3c915120d284aafba8fc4735
// dai on ropsten = 0xad6d458402f60fd3bd25163575031acdce07538d