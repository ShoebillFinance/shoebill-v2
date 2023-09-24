import * as dotenv from "dotenv";
dotenv.config();

import "@nomicfoundation/hardhat-network-helpers";
import "@nomiclabs/hardhat-waffle";
// import "@typechain/hardhat";
import "hardhat-deploy";
import "solidity-coverage";

import "./tasks";

const config = {
    solidity: {
        compilers: [
            {
                version: "0.8.16",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        hardhat: {
            // companionNetworks: {
            //     mainnet: process.env.FORKING_NETWORK?.toLowerCase()!,
            // },
            // forking: {
            //     enabled: true,
            //     url: process.env[
            //         `${process.env.FORKING_NETWORK?.toUpperCase()}_RPC_URL`
            //     ]!,
            // },
            // autoImpersonate: true,
            // gasPrice: 1000000000,
        },
        klaytnMainnet: {
            chainId: 8217,
            url: process.env.KLAYTN_RPC_URL!,
            accounts: [process.env.KLAYTN_DEPLOYER!],
        },
        wemix: {
            chainId: 1111,
            url: "https://api.wemix.com",
            accounts: [process.env.KLAYTN_DEPLOYER!],
            verify: {
                etherscan: {
                    apiUrl: "https://api.wemixscan.com",
                    apiKey: process.env.WEMIX_SCAN_API_KEY!,
                },
            },
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
};

export default config;
