import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

describe("Time Token Contract Tests", () => {
  beforeEach(() => {
    simnet.deployContract("sip010-trait", "contracts/sip010-trait.clar", null, deployer);
    simnet.deployContract("time-token", "contracts/time-token.clar", null, deployer);
  });

  describe("Contract Initialization", () => {
    it("should initialize with correct token info", () => {
      const name = simnet.callReadOnlyFn("time-token", "get-name", [], deployer);
      expect(name.result).toBeOk("HourBank Time Credits");

      const symbol = simnet.callReadOnlyFn("time-token", "get-symbol", [], deployer);
      expect(symbol.result).toBeOk("HTC");

      const decimals = simnet.callReadOnlyFn("time-token", "get-decimals", [], deployer);
      expect(decimals.result).toBeOk(6n);

      const totalSupply = simnet.callReadOnlyFn("time-token", "get-total-supply", [], deployer);
      expect(totalSupply.result).toBeOk(0n);
    });

    it("should have correct contract owner", () => {
      const { result } = simnet.callReadOnlyFn("time-token", "get-contract-owner", [], deployer);
      expect(result).toBePrincipal(deployer);
    });
  });

  describe("Token Minting", () => {
    it("should allow owner to mint tokens", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(1000), types.principal(wallet1)],
        deployer
      );
      expect(result).toBeOk(true);

      // Check balance
      const balance = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet1)],
        deployer
      );
      expect(balance.result).toBeOk(1000n);

      // Check total supply
      const totalSupply = simnet.callReadOnlyFn("time-token", "get-total-supply", [], deployer);
      expect(totalSupply.result).toBeOk(1000n);
    });

    it("should not allow non-owner to mint tokens", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(1000), types.principal(wallet1)],
        wallet1
      );
      expect(result).toBeErr(100n); // ERR_UNAUTHORIZED
    });

    it("should reject minting zero tokens", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(0), types.principal(wallet1)],
        deployer
      );
      expect(result).toBeErr(101n); // ERR_INVALID_AMOUNT
    });
  });

  describe("Token Burning", () => {
    beforeEach(() => {
      // Mint some tokens first
      simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(1000), types.principal(wallet1)],
        deployer
      );
    });

    it("should allow owner to burn tokens", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "burn",
        [types.uint(500), types.principal(wallet1)],
        deployer
      );
      expect(result).toBeOk(true);

      // Check balance
      const balance = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet1)],
        deployer
      );
      expect(balance.result).toBeOk(500n);

      // Check total supply
      const totalSupply = simnet.callReadOnlyFn("time-token", "get-total-supply", [], deployer);
      expect(totalSupply.result).toBeOk(500n);
    });

    it("should not allow burning more than balance", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "burn",
        [types.uint(2000), types.principal(wallet1)],
        deployer
      );
      expect(result).toBeErr(102n); // ERR_INSUFFICIENT_BALANCE
    });

    it("should not allow non-owner to burn tokens", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "burn",
        [types.uint(500), types.principal(wallet1)],
        wallet1
      );
      expect(result).toBeErr(100n); // ERR_UNAUTHORIZED
    });
  });

  describe("Token Transfers", () => {
    beforeEach(() => {
      // Mint tokens to wallet1
      simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(1000), types.principal(wallet1)],
        deployer
      );
    });

    it("should allow token transfers", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "transfer",
        [
          types.uint(300),
          types.principal(wallet1),
          types.principal(wallet2),
          types.none()
        ],
        wallet1
      );
      expect(result).toBeOk(true);

      // Check balances
      const balance1 = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet1)],
        deployer
      );
      expect(balance1.result).toBeOk(700n);

      const balance2 = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet2)],
        deployer
      );
      expect(balance2.result).toBeOk(300n);
    });

    it("should not allow transfers with insufficient balance", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "transfer",
        [
          types.uint(2000),
          types.principal(wallet1),
          types.principal(wallet2),
          types.none()
        ],
        wallet1
      );
      expect(result).toBeErr(102n); // ERR_INSUFFICIENT_BALANCE
    });

    it("should not allow transfers of zero amount", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "transfer",
        [
          types.uint(0),
          types.principal(wallet1),
          types.principal(wallet2),
          types.none()
        ],
        wallet1
      );
      expect(result).toBeErr(101n); // ERR_INVALID_AMOUNT
    });

    it("should not allow unauthorized transfers", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "transfer",
        [
          types.uint(300),
          types.principal(wallet1),
          types.principal(wallet2),
          types.none()
        ],
        wallet3 // wallet3 trying to transfer wallet1's tokens
      );
      expect(result).toBeErr(100n); // ERR_UNAUTHORIZED
    });
  });

  describe("Administrative Functions", () => {
    it("should allow owner to set new owner", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "set-contract-owner",
        [types.principal(wallet1)],
        deployer
      );
      expect(result).toBeOk(true);

      const owner = simnet.callReadOnlyFn("time-token", "get-contract-owner", [], deployer);
      expect(owner.result).toBePrincipal(wallet1);
    });

    it("should not allow non-owner to set new owner", () => {
      const { result } = simnet.callPublicFn(
        "time-token",
        "set-contract-owner",
        [types.principal(wallet2)],
        wallet1
      );
      expect(result).toBeErr(100n); // ERR_UNAUTHORIZED
    });
  });

  describe("Read-Only Functions", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(1000), types.principal(wallet1)],
        deployer
      );
      simnet.callPublicFn(
        "time-token",
        "mint",
        [types.uint(500), types.principal(wallet2)],
        deployer
      );
    });

    it("should return correct token URI", () => {
      const { result } = simnet.callReadOnlyFn("time-token", "get-token-uri", [], deployer);
      expect(result).toBeOk(types.some("https://hourbank.io/token-metadata.json"));
    });

    it("should return correct balances", () => {
      const balance1 = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet1)],
        deployer
      );
      expect(balance1.result).toBeOk(1000n);

      const balance2 = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet2)],
        deployer
      );
      expect(balance2.result).toBeOk(500n);

      const balance3 = simnet.callReadOnlyFn(
        "time-token",
        "get-balance",
        [types.principal(wallet3)],
        deployer
      );
      expect(balance3.result).toBeOk(0n);
    });

    it("should return correct total supply", () => {
      const { result } = simnet.callReadOnlyFn("time-token", "get-total-supply", [], deployer);
      expect(result).toBeOk(1500n);
    });
  });
});
