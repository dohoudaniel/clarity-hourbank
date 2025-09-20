import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const rater = accounts.get("wallet_1")!;
const rated = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

describe("Reputation Contract Tests", () => {
  beforeEach(() => {
    simnet.deployContract("reputation", "contracts/reputation.clar", null, deployer);
  });

  describe("Rating System", () => {
    it("should allow adding valid ratings", () => {
      const { result } = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [
          types.principal(rated),
          types.uint(1), // booking-id
          types.uint(5), // score (1-5)
          types.ascii("Excellent work!")
        ],
        rater
      );
      expect(result).toBeOk(true);

      // Check reputation was updated
      const reputation = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(rated)],
        deployer
      );
      expect(reputation.result).toBeSome({
        "total-score": 5n,
        "total-ratings": 1n,
        "average-rating": 5n
      });
    });

    it("should calculate correct average rating", () => {
      // Add multiple ratings
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(5), types.ascii("Great!")],
        rater
      );
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(2), types.uint(3), types.ascii("Good")],
        wallet3
      );
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(3), types.uint(4), types.ascii("Very good")],
        deployer
      );

      // Check average: (5 + 3 + 4) / 3 = 4
      const reputation = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(rated)],
        deployer
      );
      expect(reputation.result).toBeSome({
        "total-score": 12n,
        "total-ratings": 3n,
        "average-rating": 4n
      });
    });

    it("should reject invalid ratings", () => {
      // Score too low (0)
      const result1 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(0), types.ascii("Bad")],
        rater
      );
      expect(result1.result).toBeErr(602n); // ERR_INVALID_RATING

      // Score too high (6)
      const result2 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(6), types.ascii("Too high")],
        rater
      );
      expect(result2.result).toBeErr(602n); // ERR_INVALID_RATING

      // Invalid booking ID (0)
      const result3 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(0), types.uint(5), types.ascii("Good")],
        rater
      );
      expect(result3.result).toBeErr(603n); // ERR_INVALID_INPUT

      // Empty comment
      const result4 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(5), types.ascii("")],
        rater
      );
      expect(result4.result).toBeErr(603n); // ERR_INVALID_INPUT
    });

    it("should store individual ratings correctly", () => {
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [
          types.principal(rated),
          types.uint(1),
          types.uint(4),
          types.ascii("Good work!")
        ],
        rater
      );

      const rating = simnet.callReadOnlyFn(
        "reputation",
        "get-rating",
        [types.principal(rater), types.principal(rated), types.uint(1)],
        deployer
      );
      expect(rating.result).toBeSome({
        score: 4n,
        comment: "Good work!",
        "created-at": types.uint(simnet.blockHeight)
      });
    });
  });

  describe("Reputation Queries", () => {
    beforeEach(() => {
      // Add some test ratings
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(5), types.ascii("Excellent!")],
        rater
      );
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(2), types.uint(4), types.ascii("Very good")],
        wallet3
      );
    });

    it("should return none for users with no reputation", () => {
      const { result } = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(deployer)],
        deployer
      );
      expect(result).toBeNone();
    });

    it("should return none for non-existent ratings", () => {
      const { result } = simnet.callReadOnlyFn(
        "reputation",
        "get-rating",
        [types.principal(rater), types.principal(rated), types.uint(999)],
        deployer
      );
      expect(result).toBeNone();
    });

    it("should handle multiple users correctly", () => {
      // Add rating for another user
      simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rater), types.uint(3), types.uint(3), types.ascii("OK work")],
        rated
      );

      // Check both users have different reputations
      const reputation1 = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(rated)],
        deployer
      );
      expect(reputation1.result).toBeSome({
        "total-score": 9n,
        "total-ratings": 2n,
        "average-rating": 4n // (5 + 4) / 2 = 4.5 -> 4 (integer division)
      });

      const reputation2 = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(rater)],
        deployer
      );
      expect(reputation2.result).toBeSome({
        "total-score": 3n,
        "total-ratings": 1n,
        "average-rating": 3n
      });
    });
  });

  describe("Edge Cases", () => {
    it("should handle maximum comment length", () => {
      const longComment = "A".repeat(256); // Maximum length
      const { result } = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(5), types.ascii(longComment)],
        rater
      );
      expect(result).toBeOk(true);
    });

    it("should handle self-rating (if allowed)", () => {
      const { result } = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rater), types.uint(1), types.uint(5), types.ascii("Self rating")],
        rater
      );
      // This should work as there's no explicit check against self-rating
      expect(result).toBeOk(true);
    });

    it("should handle large booking IDs", () => {
      const { result } = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(999999), types.uint(5), types.ascii("Large booking ID")],
        rater
      );
      expect(result).toBeOk(true);
    });

    it("should handle multiple ratings for same booking from different users", () => {
      // First rating
      const result1 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(5), types.ascii("Great!")],
        rater
      );
      expect(result1.result).toBeOk(true);

      // Second rating for same booking from different user
      const result2 = simnet.callPublicFn(
        "reputation",
        "add-rating",
        [types.principal(rated), types.uint(1), types.uint(3), types.ascii("OK")],
        wallet3
      );
      expect(result2.result).toBeOk(true);

      // Both should be stored separately
      const rating1 = simnet.callReadOnlyFn(
        "reputation",
        "get-rating",
        [types.principal(rater), types.principal(rated), types.uint(1)],
        deployer
      );
      expect(rating1.result).toBeSome({
        score: 5n,
        comment: "Great!",
        "created-at": types.uint(simnet.blockHeight - 1)
      });

      const rating2 = simnet.callReadOnlyFn(
        "reputation",
        "get-rating",
        [types.principal(wallet3), types.principal(rated), types.uint(1)],
        deployer
      );
      expect(rating2.result).toBeSome({
        score: 3n,
        comment: "OK",
        "created-at": types.uint(simnet.blockHeight)
      });
    });
  });

  describe("Reputation Accumulation", () => {
    it("should accumulate reputation correctly over time", () => {
      const ratings = [
        { score: 5, comment: "Excellent!" },
        { score: 4, comment: "Very good" },
        { score: 5, comment: "Outstanding!" },
        { score: 3, comment: "Good" },
        { score: 4, comment: "Nice work" }
      ];

      let totalScore = 0;
      ratings.forEach((rating, index) => {
        simnet.callPublicFn(
          "reputation",
          "add-rating",
          [
            types.principal(rated),
            types.uint(index + 1),
            types.uint(rating.score),
            types.ascii(rating.comment)
          ],
          rater
        );
        totalScore += rating.score;
      });

      const reputation = simnet.callReadOnlyFn(
        "reputation",
        "get-reputation",
        [types.principal(rated)],
        deployer
      );
      
      const expectedAverage = Math.floor(totalScore / ratings.length);
      expect(reputation.result).toBeSome({
        "total-score": BigInt(totalScore),
        "total-ratings": BigInt(ratings.length),
        "average-rating": BigInt(expectedAverage)
      });
    });
  });
});
