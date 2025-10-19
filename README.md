# StackTrust

A prototype Clarity smart contract implementing a reputation-driven lending, bounty, and DAO governance system. This repository contains a single contract `stacktrust.clar` that tracks reputation, handles loan requests/repayments, manages bounties and milestones, and supports simple DAO proposals and voting.

## Location
contracts/stacktrust.clar
(c:\Users\USER\Desktop\STACKS\AUGUST\stacktrust\contracts\stacktrust.clar)

## Features
- Reputation ledger (award/slash)
- Loan requests, approvals, repayments, and default slashing
- Bounty posting, claiming, milestone submission, grading
- Simple DAO: submit proposals, vote yes/no, proposal counter
- Reputation staking map and basic parameters/constants

## Quick requirements
- Clarinet (for local testing)
- Stacks/Clarity toolchain for compilation and deployment
- Windows PowerShell or Command Prompt for CLI commands

## Build & Test (local)
1. Install Clarinet: https://github.com/hirosystems/clarinet
2. From project root:
   - Run tests / interactive console:
````bash
# Powershell / CMD
clarinet test
clarinet console
