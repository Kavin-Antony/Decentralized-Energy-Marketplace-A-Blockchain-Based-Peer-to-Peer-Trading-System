global.ReadableStream = require("stream/web").ReadableStream;
const Web3 = require("web3");
const contract = require("@truffle/contract");
const energyTradeArtifact = require("./build/contracts/EnergyTrade.json");

const web3 = new Web3("http://127.0.0.1:7545");

const run = async () => {
  const accounts = await web3.eth.getAccounts();
  const seller = accounts[0];
  const buyer = accounts[1];
  const owner = accounts[2];

  const EnergyTrade = contract(energyTradeArtifact);
  EnergyTrade.setProvider(web3.currentProvider);

  const instance = await EnergyTrade.deployed();

  // 1. Seller creates trade
  await instance.createTrade(10, web3.utils.toWei("2", "ether"), { from: seller });
  console.log(`✅ Trade created by seller: ${seller}`);

  // 2. Buyer accepts trade
  await instance.acceptTrade(0, {
    from: buyer,
    value: web3.utils.toWei("2", "ether"),
  });
  console.log(`✅ Trade accepted by buyer: ${buyer}`);

  // 3. Buyer completes trade
  await instance.completeTrade(0, { from: buyer });
  console.log(`✅ Trade completed by buyer`);

  // 4. (Optional) Simulate a dispute
  /*
  await instance.raiseDispute(0, { from: seller });
  console.log("🚨 Dispute raised by seller");

  await instance.resolveDispute(0, true, { from: owner });
  console.log("🧑‍⚖️ Dispute resolved in favor of seller");
  */

  // 5. Fetch and log trade
  const trade = await instance.getAllTrades();
  console.log("📦 All Trades:\n", trade);
};

run();