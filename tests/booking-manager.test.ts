import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const requester = accounts.get("wallet_1")!;
const provider = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

describe("Booking Manager Contract Tests", () => {
  beforeEach(() => {
    simnet.deployContract("booking-manager", "contracts/booking-manager.clar", null, deployer);
  });

  describe("Contract Initialization", () => {
    it("should initialize with zero bookings", () => {
      const { result } = simnet.callReadOnlyFn("booking-manager", "get-next-booking-id", [], deployer);
      expect(result).toBeUint(1n);
    });

    it("should have correct contract owner", () => {
      const { result } = simnet.callReadOnlyFn("booking-manager", "get-contract-owner", [], deployer);
      expect(result).toBePrincipal(deployer);
    });
  });

  describe("Booking Creation", () => {
    it("should create a new booking successfully", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1), // skill-id
          types.ascii("Need help with programming"),
          types.uint(100), // credits
          types.uint(simnet.blockHeight + 1000) // deadline
        ],
        requester
      );
      expect(result).toBeOk(1n); // First booking ID

      // Verify booking was created
      const booking = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking",
        [types.uint(1)],
        deployer
      );
      expect(booking.result).toBeSome({
        requester: requester,
        provider: provider,
        "skill-id": 1n,
        description: "Need help with programming",
        credits: 100n,
        deadline: types.uint(simnet.blockHeight + 1000),
        status: 1n, // BOOKING_STATUS_PENDING
        "created-at": types.uint(simnet.blockHeight),
        "completed-at": types.none(),
        "hours-worked": types.none()
      });
    });

    it("should increment booking ID for each new booking", () => {
      // Create first booking
      const result1 = simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1),
          types.ascii("First booking"),
          types.uint(100),
          types.uint(simnet.blockHeight + 1000)
        ],
        requester
      );
      expect(result1.result).toBeOk(1n);

      // Create second booking
      const result2 = simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(wallet3),
          types.uint(2),
          types.ascii("Second booking"),
          types.uint(200),
          types.uint(simnet.blockHeight + 2000)
        ],
        requester
      );
      expect(result2.result).toBeOk(2n);

      // Check next booking ID
      const nextId = simnet.callReadOnlyFn("booking-manager", "get-next-booking-id", [], deployer);
      expect(nextId.result).toBeUint(3n);
    });

    it("should reject booking with invalid inputs", () => {
      // Invalid credits (zero)
      const result1 = simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1),
          types.ascii("Test booking"),
          types.uint(0), // Invalid credits
          types.uint(simnet.blockHeight + 1000)
        ],
        requester
      );
      expect(result1.result).toBeErr(403n); // ERR_INVALID_INPUT

      // Invalid deadline (in the past)
      const result2 = simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1),
          types.ascii("Test booking"),
          types.uint(100),
          types.uint(simnet.blockHeight - 1) // Past deadline
        ],
        requester
      );
      expect(result2.result).toBeErr(403n); // ERR_INVALID_INPUT
    });
  });

  describe("Booking Status Management", () => {
    beforeEach(() => {
      // Create a test booking
      simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1),
          types.ascii("Test booking"),
          types.uint(100),
          types.uint(simnet.blockHeight + 1000)
        ],
        requester
      );
    });

    it("should allow provider to accept booking", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "accept-booking",
        [types.uint(1)],
        provider
      );
      expect(result).toBeOk(true);

      // Check status updated
      const booking = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking",
        [types.uint(1)],
        deployer
      );
      const bookingData = booking.result.expectSome();
      expect(bookingData.status).toBeUint(2n); // BOOKING_STATUS_ACCEPTED
    });

    it("should not allow non-provider to accept booking", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "accept-booking",
        [types.uint(1)],
        wallet3
      );
      expect(result).toBeErr(400n); // ERR_UNAUTHORIZED
    });

    it("should allow provider to complete booking", () => {
      // First accept the booking
      simnet.callPublicFn("booking-manager", "accept-booking", [types.uint(1)], provider);

      // Then complete it
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "complete-booking",
        [types.uint(1), types.uint(8)], // 8 hours worked
        provider
      );
      expect(result).toBeOk(true);

      // Check status and hours worked
      const booking = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking",
        [types.uint(1)],
        deployer
      );
      const bookingData = booking.result.expectSome();
      expect(bookingData.status).toBeUint(3n); // BOOKING_STATUS_COMPLETED
      expect(bookingData["hours-worked"]).toBeSome(types.uint(8));
      expect(bookingData["completed-at"]).toBeSome(types.uint(simnet.blockHeight));
    });

    it("should allow requester to cancel booking", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "cancel-booking",
        [types.uint(1)],
        requester
      );
      expect(result).toBeOk(true);

      // Check status updated
      const booking = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking",
        [types.uint(1)],
        deployer
      );
      const bookingData = booking.result.expectSome();
      expect(bookingData.status).toBeUint(4n); // BOOKING_STATUS_CANCELLED
    });
  });

  describe("Read-Only Functions", () => {
    it("should return none for non-existent booking", () => {
      const { result } = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking",
        [types.uint(999)],
        deployer
      );
      expect(result).toBeNone();
    });

    it("should return correct booking status", () => {
      // Create and accept a booking
      simnet.callPublicFn(
        "booking-manager",
        "create-booking",
        [
          types.principal(provider),
          types.uint(1),
          types.ascii("Test booking"),
          types.uint(100),
          types.uint(simnet.blockHeight + 1000)
        ],
        requester
      );
      simnet.callPublicFn("booking-manager", "accept-booking", [types.uint(1)], provider);

      const { result } = simnet.callReadOnlyFn(
        "booking-manager",
        "get-booking-status",
        [types.uint(1)],
        deployer
      );
      expect(result).toBeUint(2n); // BOOKING_STATUS_ACCEPTED
    });
  });

  describe("Administrative Functions", () => {
    it("should allow owner to set new owner", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "set-contract-owner",
        [types.principal(wallet3)],
        deployer
      );
      expect(result).toBeOk(true);

      const owner = simnet.callReadOnlyFn("booking-manager", "get-contract-owner", [], deployer);
      expect(owner.result).toBePrincipal(wallet3);
    });

    it("should not allow non-owner to set new owner", () => {
      const { result } = simnet.callPublicFn(
        "booking-manager",
        "set-contract-owner",
        [types.principal(wallet3)],
        requester
      );
      expect(result).toBeErr(400n); // ERR_UNAUTHORIZED
    });
  });
});
