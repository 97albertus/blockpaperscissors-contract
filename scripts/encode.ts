import readline from 'readline';
import { ethers } from "hardhat";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const coder = ethers.AbiCoder.defaultAbiCoder()

rl.question('Enter your hand (0 for Rock, 1 for Paper, 2 for Scissors): ', (hand) => {
  rl.question('Enter your secret: ', (secret) => {
    const handNum = parseInt(hand);
    const commit = ethers.keccak256(coder.encode(["uint8", "string"], [handNum, secret]));
    console.log(`Your hash is: ${commit}`);
    rl.close();
  });
});