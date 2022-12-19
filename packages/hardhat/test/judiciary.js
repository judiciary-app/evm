/* eslint-disable no-underscore-dangle */
const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

require("chai").use(require("chai-as-promised")).should();

describe("Judiciary", function () {
  let escrow;
  let judiciary;

  let accounts;
  let deployer;
  let judge;

  // quick fix to let gas reporter fetch data from gas station & coinmarketcap
  before((done) => {
    setTimeout(done, 5000);
  });

  before(async () => {
    accounts = await ethers.getSigners();
    deployer = accounts[0].address;
    judge = accounts[1].address;

    const Escrow = await ethers.getContractFactory("Escrow");
    escrow = await Escrow.connect(accounts[0]).deploy();

    const Judiciary = await ethers.getContractFactory("Judiciary");
    judiciary = await Judiciary.connect(accounts[0]).deploy(
      "Judiciary",
      "CONTRACT",
      [deployer, await escrow.address, deployer],
      "https://judiciary.app/contractURI.json"
    );
  });

  describe("deploys properly", function () {
    it("has correct addresses", async function () {
      expect(await escrow.address).to.not.equal("");
      expect(await escrow.address).to.not.equal(undefined);
      expect(await escrow.address).to.not.equal(null);
      expect(await escrow.address).to.not.equal(0x0);

      expect(await judiciary.address).to.not.equal("");
      expect(await judiciary.address).to.not.equal(undefined);
      expect(await judiciary.address).to.not.equal(null);
      expect(await judiciary.address).to.not.equal(0x0);
    });

    it("mints genesis contract", async function () {
      expect(await judiciary.exists(0)).to.equal(true);
    });
  });

  describe("creates & signs a contract", function () {
    let tokenId;
    let escrowWallet;
    const metadata = "ar://randomArHash1";

    it("successful contract creation", async function () {
      const contractSigner = accounts[2];
      const contractCreator = accounts[3];

      const contractCreation = await judiciary
        .connect(contractCreator)
        .createContract(
          metadata,
          [contractSigner.address, contractCreator.address],
          judge
        );

      // check if accounts[3] gets the minted tokenId
      tokenId = (await contractCreation.wait()).events
        .find(
          (event) =>
            event.event === "Transfer" &&
            event.args.to === contractCreator.address &&
            event.args.from === ethers.constants.AddressZero
        )
        .args.tokenId.toNumber();

      // check id
      expect(tokenId).to.equal(1);

      // check if an escrow wallet was created
      escrowWallet = await judiciary.getEscrowAddressByTokenId(tokenId);
      const _escrowWallet = (await contractCreation.wait()).events.find(
        (event) => event.event === "CreateContract"
      ).args.hash;
      expect(_escrowWallet).to.equal(escrowWallet);

      // console.log({
      //   escrows: await judiciary.fetchEscrowAddressesBySignerAddress(
      //     contractCreator.address
      //   ),
      //   tokenIds: await judiciary.fetchTokenIdsByEscrowAddress(escrowWallet),
      // });
    });

    it("successful contract signing", async function () {
      const contractSigner = accounts[2];

      const contractSigning = await judiciary
        .connect(contractSigner)
        .signContract(escrowWallet);

      // check if accounts[3] gets the minted tokenId
      tokenId = (await contractSigning.wait()).events
        .find(
          (event) =>
            event.event === "Transfer" &&
            event.args.to === contractSigner.address &&
            event.args.from === ethers.constants.AddressZero
        )
        .args.tokenId.toNumber();

      // check id
      expect(tokenId).to.equal(2);

      // check if an escrow wallet matches
      escrowWallet = await judiciary.getEscrowAddressByTokenId(tokenId);
      const _escrowWallet = (await contractSigning.wait()).events.find(
        (event) => event.event === "SignContract"
      ).args[0];
      expect(_escrowWallet).to.equal(escrowWallet);
    });
  });
});
