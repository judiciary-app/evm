/* eslint-disable no-undef */
// deploy/01_deploy_monument_artifacts.js

require("dotenv").config();
// const { ethers } = require("hardhat");
const ethers = require("@nomiclabs/hardhat-ethers");
const sleep = require("../scripts/sleep");

const localChainId = "31337";

// async function asyncForEach(array, callback) {
//   // eslint-disable-next-line no-plusplus
//   for (let index = 0; index < array.length; index++) {
//     // eslint-disable-next-line no-await-in-loop
//     await callback(array[index], index, array);
//   }
// }

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // Deploy Escrow Contract instance
  await deploy("Escrow", {
    from: deployer,
    // args: [],
    log: true,
  });
  const Escrow =
    (await deployments.get("Escrow")) ||
    (await ethers.getContract("Escrow", deployer));

  // Deploy Main Contract
  const mainContractArgs = [
    "Judiciary",
    "CONTRACT",
    [deployer, Escrow.address, deployer],
    "https://judiciary.app/contractURI.json",
  ];
  await deploy("Judiciary", {
    from: deployer,
    args: mainContractArgs,
    log: true,
  });
  const Main =
    (await deployments.get("Judiciary")) ||
    (await ethers.getContract("Judiciary", deployer));

  // Verify your contracts with Etherscan
  // You don't want to verify on localhost
  if (chainId !== localChainId) {
    // wait for etherscan to be ready to verify
    await sleep(15000);

    try {
      await run("verify:verify", {
        address: Escrow.address,
        contract: "contracts/Escrow.sol:Escrow",
        constructorArguments: [],
      });
    } catch (e) {
      // no worries if already verified
      console.log(e);
    }

    try {
      await run("verify:verify", {
        address: Main.address,
        contract: "contracts/Judiciary.sol:Judiciary",
        constructorArguments: mainContractArgs,
      });
    } catch (e) {
      // no worries if already verified
      console.log(e);
    }
  }
};

module.exports.tags = ["Escrow", "EscrowFactory"];
