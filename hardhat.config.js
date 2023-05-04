require("@nomicfoundation/hardhat-toolbox");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html

require('dotenv').config();

const { PRIVATE_KEY, INFURA_ID } = process.env;
let hardhatConfig = {}

module.exports = {
   defaultNetwork: "hardhat",
   networks: {
      hardhat: hardhatConfig,
      goerli: {
         url: "https://goerli.infura.io/v3/" + INFURA_ID,
         accounts: [`0x${PRIVATE_KEY}`]
      }
   },
   solidity: {
      version: "0.8.7",
      settings: {
         optimizer: {
            enabled: true,
            runs: 200,
         }
      }
   },
   etherscan: {
      // Etherscan API Key
      apiKey: "S1VH5HN4RW22314GI9APVKVFIJ36IH5SXV"
   },
   paths: {
     sources: "./contracts",
     tests: "./test",
     cache: "./cache",
     artifacts: "./artifacts"
   },
   mocha: {
     timeout: 20000
   }
}