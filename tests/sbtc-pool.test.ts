
import { describe, expect, it } from "vitest";
import { tx } from '@hirosystems/clarinet-sdk';
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;

describe("withdraw", ()=>{
  it("allows lenders withdraw their yield plus stake", ()=>{
    simnet.mineEmptyBlocks(300000) // allows time per block to work
    const block = simnet.mineBlock([
      tx.callPublicFn(
        "sbtc-pool",
        "lend",
        [
          Cl.uint(100000000),
        ],
        address2
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "apply-for-loan",
        [
          Cl.uint(10000),
        ],
        address1
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "repay-loan",
        [
          Cl.standardPrincipal(address1),
        ],
        address1
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "apply-for-loan",
        [
          Cl.uint(10000),
        ],
        address1
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "repay-loan",
        [
          Cl.standardPrincipal(address1),
        ],
        address1
      ),
    ])

    simnet.mineEmptyBlocks(300000) // accounts for reaching unlock block

    const block_2 = simnet.mineBlock([
      tx.callPublicFn(
        "sbtc-pool",
        "withdraw",
        [
          Cl.uint(100003000),
        ],
        address2
      )
    ])

    expect(block[0].result).toBeOk(Cl.bool(true))
    expect(block_2[0].result).toBeOk(Cl.bool(true))
  }, 20000)

  it("does not allow lenders withdraw before unlock block", ()=>{
    simnet.mineEmptyBlocks(1000) // allows time per block to work
    const block = simnet.mineBlock([
      tx.callPublicFn(
        "sbtc-pool",
        "lend",
        [
          Cl.uint(100000000),
        ],
        deployer
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "withdraw",
        [
          Cl.uint(100000000),
        ],
        deployer
      )
    ])

    expect(block[1].result).toBeErr(Cl.uint(106))
  })

  it("does not allow lenders withdraw more than their pool share", ()=>{
    simnet.mineEmptyBlocks(1000) // allows time per block to work
    const block = simnet.mineBlock([
      tx.callPublicFn(
        "sbtc-pool",
        "lend",
        [
          Cl.uint(100000000),
        ],
        deployer
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "lend",
        [
          Cl.uint(100000000),
        ],
        address1
      ),
      tx.callPublicFn(
        "sbtc-pool",
        "withdraw",
        [
          Cl.uint(100000001),
        ],
        deployer
      )
    ])

    expect(block[2].result).toBeErr(Cl.uint(103))
  })

  it("does not allow non lenders withdraw", ()=>{
    const block = simnet.mineBlock([
      tx.callPublicFn(
        "sbtc-pool",
        "withdraw",
        [
          Cl.uint(10),
        ],
        deployer
      )
    ])

    expect(block[0].result).toBeErr(Cl.uint(102))
  })
})

// describe("set-lock-duration-in-days ", ()=>{
//   it("does not allow lock duration to be 0", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-lock-duration-in-days",
//         [
//           Cl.uint(0),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(101))
//   })

//   it("allows an admin to set a new lock duration", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-lock-duration-in-days",
//         [
//           Cl.uint(10),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow a non admin to set a new lock duration", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-lock-duration-in-days",
//         [
//           Cl.uint(10),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(100))
//   })
// })

// describe("set-loan-duration-in-days", ()=>{
//   it("does not allow loan duration to be less than 7", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-loan-duration-in-days",
//         [
//           Cl.uint(6),
//         ],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-loan-duration-in-days",
//         [
//           Cl.uint(7),
//         ],
//         deployer
//       ),
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(101))
//     expect(block[1].result).toBeOk(Cl.bool(true))
//   })

//   it("allows an admin to set a new loan duration", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-loan-duration-in-days",
//         [
//           Cl.uint(10),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow a non admin to set a new loan duration", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-loan-duration-in-days",
//         [
//           Cl.uint(10),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(100))
//   })
// })

// describe("set-interest-rate-in-percent", ()=>{
//   it("does not allow interest rate to be 0", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-interest-rate-in-percent",
//         [
//           Cl.uint(0),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(101))
//   })

//   it("allows an admin to set a new interest rate", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-interest-rate-in-percent",
//         [
//           Cl.uint(10),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow a non admin to set a new interest rate", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-interest-rate-in-percent",
//         [
//           Cl.uint(10),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(100))
//   })
// })

// describe("set-admin", ()=>{
//   const address2 = accounts.get("wallet_2")!;

//   it("allows an admin to set a new admin", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-admin",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow a non admin to set a new admin", ()=>{
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "set-admin",
//         [
//           Cl.standardPrincipal(address2),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(100))
//   })
// })

// describe("repay-loan", ()=>{
//   it("does not debit users who don't have an active loan", ()=>{
//     simnet.mineEmptyBlocks(1000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(104))
//   }, 20000)

//   it("allows to repay their loans", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(100000000), // Amount is 1 sBTC
//         ],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//     expect(block[2].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow double payment of a paid loan", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(100000000), // Amount is 1 sBTC
//         ],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         address1
//       ),
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//     expect(block[2].result).toBeOk(Cl.bool(true))
//     expect(block[3].result).toBeErr(Cl.uint(104))
//   })
// })

// describe("lend", ()=>{
//   it("does not allow users lend below 1 sBTC", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(1000), // Amount is less than 1 sBTC
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(101))
//   })

//   it("allows  users lend 1 sBTC and above", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(100000000), // Amount is 1 sBTC
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeOk(Cl.bool(true))
//   })
// })

// describe("apply-for-loan", ()=>{ 
//   it("does not grant loans where amount equals to zero", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(0),
//         ],
//         deployer
//       )
//     ])

//     expect(block[0].result).toBeErr(Cl.uint(101))
//   })

//   it("grants loans to new users", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(100000000),
//         ],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(10000),
//         ],
//         address1
//       ),
//     ])

//     expect(block[1].result).toBeOk(Cl.bool(true))
//   })

//   it("grants loans to qualified users with repayment history", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back
//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [
//           Cl.uint(100000000),
//         ],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(10000),
//         ],
//         address1
//       ),
//     ])

//     expect(block[2].result).toBeOk(Cl.bool(true))
//   })

//   it("does not allow accounts without a repayment history that have an unpaid loan get a new loan", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back

//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(100000000)],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${100000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block[1].result).toBeOk(Cl.bool(true))
//     expect(block[2].result).toBeErr(Cl.uint(104))
//   }, 20000)

//   it("does not allow accounts with a repayment history that have an unpaid loan get a new loan", ()=>{
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back

//     const block = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(100000000)],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       )
//     ])

//     expect(block[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${100000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block[1].result).toBeOk(Cl.bool(true))
//     expect(block[2].result).toBeErr(Cl.uint(104))
//   })

//   it("does not allow accounts without a repayment history to get loans above their average balance in the last 3 months", ()=>{
//     simnet.mineEmptyBlocks(1000) // allows for time per block calculations to work

//     const block_1 = simnet.mineBlock([ // simulaneously lend and empty account to reduce the average balance after 3 months
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(1000000000)],
//         deployer
//       ),

//     ])
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back

//     const block_2 = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         deployer
//       ),
//     ])

//     expect(block_1[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${1000000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block_2[0].result).toBeErr(Cl.uint(104))
//   })

//   it("does not allow accounts with a repayment history to get loans above their average balance in the last 3 months", ()=>{
//     simnet.mineEmptyBlocks(1000) // allows for time per block calculations to work
  
//     const block_1 = simnet.mineBlock([ // lend 
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(1000000000)],
//         deployer
//       ),

//     ])
//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back

//     const block_2 = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1)
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(999998900)], // empty the address to reduce average balance
//         address1
//       ),
//     ])

//     simnet.mineEmptyBlocks(300000) // accounts for average time per block private function and calculating block amount 3 months back

//     const block_3 = simnet.mineBlock([
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000),
//         ],
//         address1
//       ),
//     ])

//     expect(block_1[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${1000000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block_2[0].result).toBeOk(Cl.bool(true))
//     expect(block_2[1].result).toBeOk(Cl.bool(true))
//     expect(block_2[2].result).toBeOk(Cl.bool(true))
//     expect(block_2[2].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${999998900}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${address1}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block_3[0].result).toBeErr(Cl.uint(104))
//   }, 20000)

//   it("does not allow accounts without a repayment history to get loans above their credit score limit", ()=>{
//     simnet.mineEmptyBlocks(300000) //  // accounts for average time per block private function and calculating block amount 3 months back

//     const block = simnet.mineBlock([ // simulaneously lend and empty account to reduce the average balance after 3 months
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(1000000000)],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(10001), // just one satoshi above the limit
//         ],
//         address1
//       ),

//     ])

//     expect(block[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${1000000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block[1].result).toBeErr(Cl.uint(104))
//   }, 20000)

//   it("does not allow accounts with a repayment history to get loans above their credit score limit", ()=>{
//     simnet.mineEmptyBlocks(300000) //  // accounts for average time per block private function and calculating block amount 3 months back

//     const block = simnet.mineBlock([ // simulaneously lend and empty account to reduce the average balance after 3 months
//       tx.callPublicFn(
//         "sbtc-pool",
//         "lend",
//         [Cl.uint(1000000000)],
//         deployer
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(1000), // just one satoshi above the limit
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "repay-loan",
//         [
//           Cl.standardPrincipal(address1)
//         ],
//         address1
//       ),
//       tx.callPublicFn(
//         "sbtc-pool",
//         "apply-for-loan",
//         [
//           Cl.uint(50001), // just one satoshi above the limit
//         ],
//         address1
//       ),
//     ])

//     expect(block[0].events[0]).toStrictEqual({
//       "data": {
//         "amount": `${1000000000}`,
//         "asset_identifier": "ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token::sbtc-token",
//         "recipient": `${deployer}.sbtc-pool`,
//         "sender": `${deployer}`,
//       },
//       "event": "ft_transfer_event",
//     })
//     expect(block[3].result).toBeErr(Cl.uint(104))
//   }, 20000)
// })
