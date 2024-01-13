import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
dotenv.config();

const INFURA_API_KEY = process.env.INFURA_API_KEY!;
const PRIVATE_KEY = process.env.SECRET_KEY!;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY!;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      }
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    optimismGoerli: {
      url: `https://optimism-goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    arbitrumGoerli: {
      url: `https://arbitrum-goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
  }

};

export default config;
