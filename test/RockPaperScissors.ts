import { expect } from "chai";
import { ethers } from "hardhat";

describe("RockPaperScissors", function () {
    let RockPaperScissors;
    let contract;
    let addr1;
    let addr2;
    let addrs;
    const coder = ethers.AbiCoder.defaultAbiCoder()
  
    beforeEach(async function () {
      RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");
      [addr1, addr2, ...addrs] = await ethers.getSigners();
      contract = await RockPaperScissors.deploy();
    });
  
    describe("startGame", function () {
      it("Should start a game correctly", async function () {
        const hand = 0; // Rock
        const secret = "secret";
        const commit = ethers.keccak256(coder.encode(["uint8", "string"], [hand, secret]));
        await contract.connect(addr1).startGame(commit, ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
        const game = await contract.getGame(0);
        expect(game.player1).to.equal(addr1.address);
        expect(game.bet).to.equal(ethers.parseEther("0.001"));
        expect(game.player1HandCommit).to.equal(commit);
      });
  
      it("Should fail if bet is less than minimum", async function () {
        const hand = 0; // Rock
        const secret = "secret";
        const commit = ethers.keccak256(coder.encode(["uint8", "string"], [hand, secret]));
        await expect(contract.connect(addr1).startGame(commit, ethers.parseEther("0.0001"), { value: ethers.parseEther("0.0001") })).to.be.revertedWith("Bet amount is less than the minimum bet");
      });
    });
  
    describe("joinGame", function () {
      beforeEach(async function () {
        const hand = 0; // Rock
        const secret = "secret";
        const commit = ethers.keccak256(coder.encode(["uint8", "string"], [hand, secret]));
        await contract.connect(addr1).startGame(commit, ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
      });
  
      it("Should join a game correctly", async function () {
        await contract.connect(addr2).joinGame(0, 1, { value: ethers.parseEther("0.001") });
        const game = await contract.getGame(0);
        expect(game.player2).to.equal(addr2.address);
        expect(game.player2Hand).to.equal(1);
      });
  
      it("Should fail if game is not available", async function () {
        await expect(contract.connect(addr2).joinGame(1, 1, { value: ethers.parseEther("0.001") })).to.be.revertedWith("Game not available");
      });
  
      it("Should fail if bet amount is incorrect", async function () {
        await expect(contract.connect(addr2).joinGame(0, 1, { value: ethers.parseEther("0.5") })).to.be.revertedWith("Incorrect bet amount");
      });
    });
  
    describe("revealHand", function () {
        beforeEach(async function () {
          const hand = 0; // Rock
          const secret = "secret";
          const commit = ethers.keccak256(coder.encode(["uint8", "string"], [hand, secret]));
          await contract.connect(addr1).startGame(commit, ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
          await contract.connect(addr2).joinGame(0, 1, { value: ethers.parseEther("0.001") });
        });
      
        it("Should reveal hand correctly", async function () {
          const hand = 0; // Rock
          const secret = "secret";
          await expect(contract.connect(addr1).revealHand(0, hand, secret))
            .to.emit(contract, 'GameFinished')
            .withArgs(0, addr2.address, 1); // 1 is the enum value for NormalEnd
        });
      
        it("Should fail if not player's game", async function () {
          const hand = 0; // Rock
          const secret = "secret";
          await expect(contract.connect(addr2).revealHand(0, hand, secret)).to.be.revertedWith("Not your game");
        });
    });
  
  describe("claimTimeout", function () {
    beforeEach(async function () {
      await contract.connect(addr1).startGame(ethers.encodeBytes32String("rock"), ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
      await contract.connect(addr2).joinGame(0, 1, { value: ethers.parseEther("0.001") });
    });
  
    it("Should claim timeout correctly", async function () {
      await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 24 hours
      await ethers.provider.send("evm_mine"); // Mine the next block
      await expect(contract.connect(addr2).claimTimeout(0))
        .to.emit(contract, 'GameFinished')
        .withArgs(0, addr2.address, 3); // 3 is the enum value for RevealTimedOut
    });
  
    it("Should fail if not enough time has passed", async function () {
      await expect(contract.connect(addr2).claimTimeout(0)).to.be.revertedWith("Cannot claim timeout yet");
    });
  });
  
  describe("cancelGame", function () {
    beforeEach(async function () {
      await contract.connect(addr1).startGame(ethers.encodeBytes32String("rock"), ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
    });
  
    it("Should cancel game correctly", async function () {
      await expect(contract.connect(addr1).cancelGame(0))
        .to.emit(contract, 'GameCancelled')
        .withArgs(0);
    });
  
    it("Should fail if not player's game", async function () {
      await expect(contract.connect(addr2).cancelGame(0)).to.be.revertedWith("Not your game");
    });
  });
  
  describe("getGamesCount", function () {
    it("Should return correct games count", async function () {
      await contract.connect(addr1).startGame(ethers.encodeBytes32String("rock"), ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
      const count = await contract.getGamesCount();
      expect(count).to.equal(1);
    });
  });
  
  describe("getGamesOfPlayer", function () {
    it("Should return correct games of player", async function () {
      await contract.connect(addr1).startGame(ethers.encodeBytes32String("rock"), ethers.parseEther("0.001"), { value: ethers.parseEther("0.001") });
      const games = await contract.getGamesOfPlayer(addr1.address);
      expect(games).to.deep.equal([0]);
    });
  });
});