/*
    PRRMIG001, Miguel Pereira
    Aims:
        - Create an ownable, ERC20 compliant contract that implements a token called Co Token
        - Implement some custom functions specified in the questions
        - Write some tests for the contract (see questions)
        - Deploy network to ganache test network
*/

pragma solidity >= 0.5.0 <0.6.4;

// Imports
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';

/// Create contract
contract CoToken is IERC20, Ownable {
    // import a lib:
    using SafeMath for uint256;

    /// Define private methods and fields
    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private approved;
    uint256 private totalNumCoins = 0; // note that the value would default to zero in any case
    uint256 private maxCoinSupply = 100;

    function _transfer(address _from, address _to, uint256 _value) private returns (bool) {
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        // fire off the transfer event
        emit Transfer(_from, _to, _value);
        return true;
    }

    function _returnPrice(uint256 _futureSupply, uint256 _currentSupply) private pure returns (uint256) {
        // implement simplified defnite integral equation
        uint256 ratio1 = 5*(10**15);
        uint256 ratio2 = 2*(10**17);
        uint256 partA = uint256(_futureSupply**2).sub(_currentSupply**2);
        partA = partA.mul(ratio1);
        uint256 partB = uint256(_futureSupply).sub(_currentSupply);
        partB = partB.mul(ratio2);
        return (partA.add(partB)); //i.e. return answer in wei
    }

    /// Public Interface

    /// Implement the IERC20 interface from OpenZeppelin

    /// Return the total number of coins in existence
    function totalSupply() external view returns (uint256) {
        return (totalNumCoins);
    }

    /// Return the balance or num tokens owned by a specified address
    function balanceOf(address _address) external view returns (uint256) {
        return (balances[_address]);
    }

    /// Returns the amount that an approved address is allowed to withdraw from the owner's account
    /// @param _owner        Person who owns the address
    /// @param _spender      Person who has been approved to make a withdrawal from the owner's account
    function allowance(address _owner, address _spender) external view returns (uint256) {
            return (approved[_owner][_spender]);
        }

    /// Transfer tokens from one account to another. Transfers of zero tokens must be allowed and fire a transfer event.
    /// @param _to       the account that the tokens are being sent to
    /// @param _value    the amount being sent to the address '_to'
    function transfer(address _to, uint256 _value) external returns (bool) {
        require (balances[msg.sender] >= _value, "Transfer failed due to insufficient funds");
        // do transfer
        return _transfer(msg.sender, _to, _value);
    }

    /// Transfer accounts from an owner to an approved beneficiary.
    /// Require that the beneficiary be on the approved list and receive less than or equal to the amount approved by the owner
    /// @param _from        The account sending the tokens
    /// @param _to          The account receiving the tokens
    /// @param _value       The amount of tokens being sent
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(balances[_from] >= _value, "Transaction failed. Insufficient funds to complete transaction");
        require(approved[_from][_to] <= _value, "Amount requested must be equal to specified allowance.");
        // do effects: update the allowance that the _to address has left to spend
        approved[_from][_to] = approved[_from][_to].sub(_value);
        // now make transfer, which includes more effects
        return _transfer(_from, _to, _value);
    }

    /// Add someone to the approved list and allow them to spend certain amount of ether on behalf of the owner
    /// @param  _spender      The nominated account that can spend on behalf of owner (i.e. withdraw funds from owner's account)
    /// @param  _value        The amount that they're allowed to spend/withdraw
    function approve(address _spender, uint256 _value) external returns (bool) {
        // for safety reasons, set allowance to zero first
        approved[msg.sender][_spender] = 0;
        // add the spender and value to the list of approved people for the account that called this function
        approved[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); // emit approval event
        return true;
    }

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value );


    /// implement other public functions
    /// Calculate the cost of buying numCo Co's, using a token bonding curve: price = 0.01x + 0.2
    function buyPrice(uint256 _numTokens) public view returns (uint256) {
        require (_numTokens > 0, "Cannot purchase a negative amount of coins");
        uint256 currentSupply = totalNumCoins;
        uint256 futureSupply = currentSupply.add(_numTokens);
        uint256 val = _returnPrice(futureSupply, currentSupply);
        return val;
    }

    /// Calculate the earnings from selling some Co Tokens, using a token bonding curve: selling price = 0.01x + 0.2
    function sellPrice(uint256 _numTokens) public view returns (uint256) {
        uint256 currentSupply = totalNumCoins;
        uint256 futureSupply = currentSupply.sub(_numTokens);
        // note how they're being swopped around! Can do this because selling curve is the same as buying curve. This avoids safemath subtraction errors.
        return (_returnPrice(currentSupply, futureSupply));
    }

    /// Purchase some Co Tokens. Caller must attach the precise amount of Eth for the transaction to pass.
    function mint(uint256 _numTokens) external payable returns (bool) {
        require (_numTokens >= 1, "Transaction failed. Cannot mint less than 1 token.");
        require (msg.value == buyPrice(_numTokens), "Transaction failed. Incorrect amount of ether transferred.");
        require (_numTokens + totalNumCoins <= maxCoinSupply, "Transaction failed. Token supply limit has been reached.");
        totalNumCoins = totalNumCoins.add(_numTokens);
        balances[msg.sender] += _numTokens; // no need for safe math because no risk of overflow. NumTokens AA capped at 100.
        return true;
    }

    /// Burn tokens, i.e. remove them from the supply and payout the value in eth to the minter
    /// Only the minter can call this function. They can only burn as many tokens as there are in ciruclation.
    /// Have to use checks-effects-interactions pattern to precent reentrancy attacks from minter (in this case, double burns).
    function burn(uint256 _numTokens) external onlyOwner returns (bool) {
        require (_numTokens <= totalNumCoins, "Transaction failed. Cannot withdraw more tokens than the total supply");
        // do effects: reduce the total number of tokens in circulation.
        // first make sure to get the selling price though!
        uint256 weiToTransfer = sellPrice(_numTokens);
        totalNumCoins = totalNumCoins.sub(_numTokens);
        // now do the external calls
        (bool success,) = (msg.sender).call.value(weiToTransfer)("");
        require (success, "Burn operation has failed. Are you payable?");
        emit Burned(msg.sender, _numTokens, weiToTransfer, totalNumCoins);
        return true;
    }

    /// Destroy the contract. Results in all of the ether that was sent to the contract being paid out to the minter.
    /// The function may only be called by the owner/minter, assuming that they own all of the tokens currently in supply
    function destroy() external onlyOwner {
        // first check if Co owns all of the tokens:
        require (balances[msg.sender] == totalNumCoins, "Owner must own all tokens in circulation to call destruct.");
        // destroy the contract and payout all of the ether to Co.
        // note that for Co to ever call this function, he'd make a loss, since he'd have to buy all of the available tokens first and pay gas costs.
        selfdestruct(msg.sender);
        emit Destroy(msg.sender, totalNumCoins);
    }

    /// Probably good practice to emit an event whenever the owner chooses to burn some tokens.
    event Burned (
        address _owner,
        uint256 _numTokens,
        uint256 _sellingPrice,
        uint256 _numTokensLeft
    );
    /// Again, probably best to emit an event when the contract is destroyed.
    event Destroy (
        address _owner,
        uint256 _numTokensWhenDestroyCalled
    );
}
