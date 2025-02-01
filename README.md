# LoopFund

A decentralized mutual lending platform for microloans built on Stacks. This contract enables users to:

- Create loan requests specifying amount and repayment terms
- Fund loan requests
- Track and process loan repayments
- Earn interest for lending
- Provide collateral for loans
- Build credit scores through successful repayments

The platform facilitates peer-to-peer microloans in a transparent and trustless manner.

## Features
- Loan request creation and funding
- Repayment tracking and processing 
- Interest calculation and distribution
- Loan status tracking
- Collateral-backed loans
- Credit scoring system
- Loan liquidation for defaults

## Credit Scoring System
- Users start with a base score of 500
- Successful repayments increase score by 50 points
- Defaults decrease score by 100 points
- Scores range from 0-1000
- Higher scores may qualify for better loan terms

## Collateral Requirements
- Minimum 50% collateral required for all loans
- Collateral is locked in contract during loan period
- Returned to borrower upon full repayment
- Transferred to lender upon default and liquidation

## Getting Started
1. Clone the repository
2. Install dependencies with `clarinet install`
3. Run tests with `clarinet test`
