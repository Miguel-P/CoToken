// imports
const truffleAssert = require('truffle-assertions');

const CoToken = artifacts.require("./CoToken.sol");

contract('CoToken', function(accounts) {

  let CoTokenInstance

  // setup and tear-down
  beforeEach(async function () {
    /// note that we make accounts[0] the minter
    CoTokenInstance = await CoToken.new({from: accounts[0]})
  })

  /// Test 1: Test mint function
  it ('Should allow anyone to mint tokens provided they pay up.', async function () {
    let price = await CoTokenInstance.buyPrice.call(1, {from: accounts[1]})
    let success = await CoTokenInstance.mint.call(1, {value: price, from: accounts[0]})
    assert(success == true, "Mint operation failed for some reason");
    // check another account
    let success2 = await CoTokenInstance.mint.call(1, {value: price, from: accounts[1]})
    assert(success2 == true, "Mint operation failed for some reason");
  })
  it ('Should allow anyone to mint more than one token provided they pay up', async function () {
    var numCoins = 100
    let price = await CoTokenInstance.buyPrice.call(numCoins, {from: accounts[1]})
    let success = await CoTokenInstance.mint.call(numCoins, {value: price, from: accounts[1]})
    assert(success == true, "Mint operation failed for some reason")
  })
  it ('Should fail if you try and mint less than 1 coin', async function () {
    truffleAssert.fails(CoTokenInstance.mint(-1, {value: web3.utils.toWei("0.205", "ether"), from: accounts[0]}))
    truffleAssert.fails(CoTokenInstance.mint(0, {value: web3.utils.toWei("0.205", "ether"), from: accounts[0]}), "Transaction failed. Cannot mint less than 1 token.")
    truffleAssert.fails(CoTokenInstance.mint(0.4, {value: web3.utils.toWei("0.205", "ether"), from: accounts[0]}))
  })
  it ('Should fail to mint if the user does not pay correct amount', async function () {
    truffleAssert.fails(CoTokenInstance.mint(1, {value: web3.utils.toWei("0.01", "ether"), from: accounts[1]}), "Transaction failed. Incorrect amount of ether transferred.")
    truffleAssert.fails(CoTokenInstance.mint(1, {value: web3.utils.toWei("88", "ether"), from: accounts[1]}), "Transaction failed. Incorrect amount of ether transferred.")
  })
  it ('Should fail if an account tries to mint more than the supply limit of 100 tokens', async function () {
    var price = await CoTokenInstance.buyPrice.call(101, {from: accounts[0]})
    truffleAssert.fails(CoTokenInstance.mint(101, {value: price, from: accounts[3]}), "Transaction failed. Token supply limit has been reached.")
  })

  /// Test 2: Test burn function
  it ('Should fail if anyone other than the minter tries to burn a token', async function () {
    // first mint some tokens and make sure that the minter owns them
    let price = await CoTokenInstance.buyPrice.call(50, {from: accounts[1]})
    await CoTokenInstance.mint(50, {value: price, from: accounts[0]})
    truffleAssert.fails(CoTokenInstance.burn(1, {from: accounts[1]}))
  })
  it ('Should let the minter burn as many tokens as there are in circulation', async function () {
    var numTokensBurned = 50
    let price = await CoTokenInstance.buyPrice.call(numTokensBurned, {from: accounts[0]})
    await CoTokenInstance.mint(numTokensBurned, {value: price, from: accounts[0]})
    var minterBalanceAfterMint = await web3.eth.getBalance(accounts[0])
    let sellingPrice = await CoTokenInstance.sellPrice.call(numTokensBurned)
    let eventReceipt = await CoTokenInstance.burn(numTokensBurned, {from: accounts[0]})
    truffleAssert.eventEmitted(eventReceipt, "Burned", (ev) => {
      return (ev._sellingPrice == sellingPrice.toString() && ev._numTokens == numTokensBurned && ev._owner == accounts[0].toString() && ev._numTokensLeft.toString() == 0)
    }, 'Burned event should reflect correct parameters and vallidates that the transaction went through');
    // test that the value of eth in the minters account increases after burning tokens:
    var minterBalanceAfterBurn = await web3.eth.getBalance(accounts[0]);
    assert(minterBalanceAfterBurn.toString() > minterBalanceAfterMint.toString(), "Minter balance must increase after burning.")
  })
  it ('Should fail if the minter tries to burn more tokens than there currently are in supply', async function () {
    // first mint some tokens and make sure that the minter owns them
    let price = await CoTokenInstance.buyPrice.call(50, {from: accounts[1]})
    await CoTokenInstance.mint(50, {value: price, from: accounts[0]})
    // check that it fails and check that the failure message is correct.
    truffleAssert.fails(CoTokenInstance.burn(99, {from: accounts[0]}), "Transaction failed. Cannot withdraw more tokens than the total supply")
  })

  /// Test 3: Test destroy function
  it ('Should fail if anyone other than the minter tries to call destory()', async function () {
    truffleAssert.fails(CoTokenInstance.destroy({from: accounts[1]}))
  })
  it ('Should fail if the minter tries to call destroy but does not own all of the tokens in circulation', async function () {
    // have the minter buy some coins
    var price1 = await CoTokenInstance.buyPrice.call(33, {from: accounts[0]})
    await CoTokenInstance.mint(33, {value: price1, from: accounts[0]})
    // now buy some coins from another account
    var price2 = await CoTokenInstance.buyPrice.call(2, {from: accounts[6]})
    await CoTokenInstance.mint(2, {value: price2, from: accounts[6]})
    // now try to destroy and check that the failure message is what we think it should be
    truffleAssert.fails(CoTokenInstance.destroy({from: accounts[0]}), "Owner must own all tokens in circulation to call destruct.")
  })
  it ('Should succeed if the minter calls destroy() and owns all coins in circulation', async function () {
    var price = await CoTokenInstance.buyPrice.call(10, {from: accounts[0]})
    // save the balance of the minter before they make the purchase:
    var minterBalanceBefore = await web3.eth.getBalance(accounts[0]);
    await CoTokenInstance.mint(10, {value: price, from: accounts[0]})
    // verify as a sanity check that the value in the account has decreased by at least price
    var minterBalanceAfterPurchase = await web3.eth.getBalance(accounts[0])
    assert(minterBalanceBefore - minterBalanceAfterPurchase > price, "The minters account must decrease after purchasing tokens.")
    // now call destroy and verify that the money gets paid back into their account. Note that the amount left in the account after destroy is still less than when we started because of the gas costs
    await CoTokenInstance.destroy({from: accounts[0]})
    var minterBalanceAfterDestroy = await web3.eth.getBalance(accounts[0])
    assert(minterBalanceAfterDestroy - minterBalanceAfterPurchase > 0, "The minters account balance must increase after destroying the contract")
  })
})
