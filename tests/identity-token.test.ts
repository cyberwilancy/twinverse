import { describe, it, expect, beforeEach } from "vitest"

type Result<T> = { value: T } | { error: number }

interface MockContract {
  admin: string
  paused: boolean
  totalSupply: bigint
  balances: Map<string, bigint>
  staked: Map<string, bigint>
  MAX_SUPPLY: bigint

  isAdmin: (caller: string) => boolean
  setPaused: (caller: string, pause: boolean) => Result<boolean>
  mint: (caller: string, recipient: string, amount: bigint) => Result<boolean>
  burn: (caller: string, amount: bigint) => Result<boolean>
  transfer: (caller: string, recipient: string, amount: bigint) => Result<boolean>
  stake: (caller: string, amount: bigint) => Result<boolean>
  unstake: (caller: string, amount: bigint) => Result<boolean>
  getBalance: (account: string) => bigint
  getStaked: (account: string) => bigint
}

// Constants for mock addresses
const ADMIN = "ST1ADMINMOCKADDRESS00000000000000000000000"
const USER1 = "ST2USER1MOCKADDRESS00000000000000000000000"
const USER2 = "ST3USER2MOCKADDRESS00000000000000000000000"

const mockContract: MockContract = {
  admin: ADMIN,
  paused: false,
  totalSupply: 0n,
  balances: new Map(),
  staked: new Map(),
  MAX_SUPPLY: 100_000_000n * 10n ** 6n, // Account for 6 decimals

  isAdmin(caller: string): boolean {
    return caller === this.admin
  },

  setPaused(caller: string, pause: boolean): Result<boolean> {
    if (!this.isAdmin(caller)) return { error: 100 }
    this.paused = pause
    return { value: pause }
  },

  mint(caller: string, recipient: string, amount: bigint): Result<boolean> {
    if (!this.isAdmin(caller)) return { error: 100 }
    if (recipient === "SP000000000000000000002Q6VF78") return { error: 105 }
    const newSupply = this.totalSupply + amount
    if (newSupply > this.MAX_SUPPLY) return { error: 103 }
    this.totalSupply = newSupply
    const current = this.balances.get(recipient) || 0n
    this.balances.set(recipient, current + amount)
    return { value: true }
  },

  burn(caller: string, amount: bigint): Result<boolean> {
    if (this.paused) return { error: 104 }
    const balance = this.balances.get(caller) || 0n
    if (balance < amount) return { error: 101 }
    this.balances.set(caller, balance - amount)
    this.totalSupply -= amount
    return { value: true }
  },

  transfer(caller: string, recipient: string, amount: bigint): Result<boolean> {
    if (this.paused) return { error: 104 }
    if (recipient === "SP000000000000000000002Q6VF78") return { error: 105 }
    const senderBalance = this.balances.get(caller) || 0n
    if (senderBalance < amount) return { error: 101 }
    this.balances.set(caller, senderBalance - amount)
    const receiverBalance = this.balances.get(recipient) || 0n
    this.balances.set(recipient, receiverBalance + amount)
    return { value: true }
  },

  stake(caller: string, amount: bigint): Result<boolean> {
    if (this.paused) return { error: 104 }
    const balance = this.balances.get(caller) || 0n
    if (balance < amount) return { error: 101 }
    this.balances.set(caller, balance - amount)
    const stakedBal = this.staked.get(caller) || 0n
    this.staked.set(caller, stakedBal + amount)
    return { value: true }
  },

  unstake(caller: string, amount: bigint): Result<boolean> {
    if (this.paused) return { error: 104 }
    const stakedBal = this.staked.get(caller) || 0n
    if (stakedBal < amount) return { error: 102 }
    this.staked.set(caller, stakedBal - amount)
    const balance = this.balances.get(caller) || 0n
    this.balances.set(caller, balance + amount)
    return { value: true }
  },

  getBalance(account: string): bigint {
    return this.balances.get(account) || 0n
  },

  getStaked(account: string): bigint {
    return this.staked.get(account) || 0n
  }
}

// ------------------------
//        TEST CASES
// ------------------------

describe("TwinVerse Token Contract", () => {
  beforeEach(() => {
    mockContract.balances.clear()
    mockContract.staked.clear()
    mockContract.totalSupply = 0n
    mockContract.paused = false
  })

  it("allows admin to mint tokens", () => {
    const result = mockContract.mint(ADMIN, USER1, 1_000n)
    expect(result).toEqual({ value: true })
    expect(mockContract.getBalance(USER1)).toBe(1_000n)
  })

  it("prevents non-admin from minting", () => {
    const result = mockContract.mint(USER1, USER1, 1_000n)
    expect(result).toEqual({ error: 100 })
  })

  it("rejects minting over MAX_SUPPLY", () => {
    const result = mockContract.mint(ADMIN, USER1, mockContract.MAX_SUPPLY + 1n)
    expect(result).toEqual({ error: 103 })
  })

  it("transfers tokens between users", () => {
    mockContract.mint(ADMIN, USER1, 1_000n)
    const result = mockContract.transfer(USER1, USER2, 600n)
    expect(result).toEqual({ value: true })
    expect(mockContract.getBalance(USER1)).toBe(400n)
    expect(mockContract.getBalance(USER2)).toBe(600n)
  })

  it("prevents transfer when paused", () => {
    mockContract.mint(ADMIN, USER1, 1_000n)
    mockContract.setPaused(ADMIN, true)
    const result = mockContract.transfer(USER1, USER2, 100n)
    expect(result).toEqual({ error: 104 })
  })

  it("burns tokens correctly", () => {
    mockContract.mint(ADMIN, USER1, 1_000n)
    const result = mockContract.burn(USER1, 300n)
    expect(result).toEqual({ value: true })
    expect(mockContract.getBalance(USER1)).toBe(700n)
    expect(mockContract.totalSupply).toBe(700n)
  })

  it("stakes tokens", () => {
    mockContract.mint(ADMIN, USER1, 1_000n)
    const result = mockContract.stake(USER1, 400n)
    expect(result).toEqual({ value: true })
    expect(mockContract.getStaked(USER1)).toBe(400n)
    expect(mockContract.getBalance(USER1)).toBe(600n)
  })

  it("unstakes tokens", () => {
    mockContract.mint(ADMIN, USER1, 1_000n)
    mockContract.stake(USER1, 400n)
    const result = mockContract.unstake(USER1, 200n)
    expect(result).toEqual({ value: true })
    expect(mockContract.getStaked(USER1)).toBe(200n)
    expect(mockContract.getBalance(USER1)).toBe(800n)
  })

  it("fails to unstake more than staked", () => {
    mockContract.mint(ADMIN, USER1, 500n)
    mockContract.stake(USER1, 300n)
    const result = mockContract.unstake(USER1, 500n)
    expect(result).toEqual({ error: 102 })
  })
})
