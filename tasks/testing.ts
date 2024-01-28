import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import Environment from "models/Configuration";
import { encodeBytes32String } from "ethers";
import { string } from "hardhat/internal/core/params/argumentTypes";

export const quickTest = task("quick-test", "Random quick testing function")
  .addOptionalParam(
    "args",
    "Contract initialize function's arguments if any",
    undefined,
    types.json,
  )
  .setAction(async ({ args }, hre: HardhatRuntimeEnvironment) => {
    if (args) {
      // example: npx hardhat quick-test --args '[12, "hello"]'
      console.log(
        "RAW Args: ",
        args,
        typeof args[0],
        args[0],
        typeof args[1],
        args[1],
      );
    }
    const env = new Environment(hre);
    //! ADD ANY TESTING CODE HERE
    const str =
      "EcdsaSecp256k1VerificationKey2019asdfasdfasdfasdfadsfasdfadsfasdfasdfadsfadsfadf";
    function _encodeBytes32String(
      inputString: string,
      finalLenght?: number,
    ): string[] {
      const stringArray = _splitString(inputString, 31);
      if (finalLenght) {
        if (stringArray.length > finalLenght) {
          throw new Error(
            `The final length provided is smaller than the number of chunks in the string. Final length: ${finalLenght}, String chunks: ${stringArray.length}`,
          );
        }
        for (let i = stringArray.length; i < finalLenght; i++) {
          stringArray.push("");
        }
      }
      console.log("String array: ", stringArray);
      const encoded = stringArray.map((s) => encodeBytes32String(s));
      return encoded;
    }

    function _splitString(
      inputString: string,
      chunkSize: number = 31,
    ): string[] {
      const result: string[] = [];
      for (let i = 0; i < inputString.length; i += chunkSize) {
        const chunk = inputString.substring(i, i + chunkSize);
        result.push(chunk);
      }
      return result;
    }

    function convertToTuple<T extends string[]>(
      array: T,
      length: number,
    ): T | null {
      if (
        array.length === length &&
        array.every((item) => typeof item === "string")
      ) {
        return array;
      } else {
        // Handle the case where the conversion is not possible
        return null;
      }
    }

    console.log("Encoded: ", _encodeBytes32String(str, 3));
    console.log(
      "Encoded touple: ",
      convertToTuple(_encodeBytes32String(str, 3), 3),
    );
    //! ------------------------
    console.log("Latest block: ", await hre.ethers.provider.getBlockNumber());
    console.log(
      "First accounts: ",
      await (await hre.ethers.provider.getSigner(0)).getAddress(),
      await (await hre.ethers.provider.getSigner(1)).getAddress(),
    );
    console.log(
      "First account balance: ",
      await hre.ethers.provider.getBalance(
        await (await hre.ethers.provider.getSigner(0)).getAddress(),
      ),
    );
  });

task("get-timestamp", "get the current timestamp in seconds")
  .addOptionalParam(
    "timeToAdd",
    "time to add to the timestamp in seconds",
    0,
    types.int,
  )
  .setAction(async ({ timeToAdd }) => {
    const currentTimestamp = Math.floor(Date.now() / 1000) + timeToAdd;
    console.log("The current timestamp in seconds is: ", currentTimestamp);
  });
