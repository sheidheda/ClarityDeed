# ClarityDeed

## Overview
ClarityDeed is a smart contract designed for tokenizing real estate assets on the blockchain. It facilitates secure and verified property ownership transfers using Clarity smart contracts, ensuring transparency, immutability, and security in real estate transactions.

## Features
- **Property Deed Registration**: Owners can register real estate properties on the blockchain.
- **Ownership Transfers**: Properties can be bought, sold, and transferred securely.
- **Escrow Mechanism**: Funds are held in escrow until all approvals are met.
- **Notary Verification**: Only authorized notaries can verify and approve transfers.
- **Property Listings**: Owners can list and delist properties for sale.
- **Contract Management**: The contract owner can add or remove notaries and transfer contract ownership.

## Data Structures
- **property-deeds**: Stores property information, including owner, valuation, and transfer history.
- **authorized-notaries**: Tracks notaries authorized to verify transactions.
- **escrow-transfers**: Manages property transactions in escrow until approvals are completed.
- **contract-owner**: The entity managing notary authorizations and contract ownership.

## Error Codes
- `ERR-NOT-AUTHORIZED (u100)`: Action requires special permissions.
- `ERR-PROPERTY-NOT-FOUND (u101)`: Property does not exist.
- `ERR-PROPERTY-EXISTS (u102)`: Property ID already registered.
- `ERR-NOT-OWNER (u103)`: Action can only be performed by the owner.
- `ERR-NOT-FOR-SALE (u104)`: Property is not listed for sale.
- `ERR-INSUFFICIENT-FUNDS (u105)`: Buyer has insufficient STX balance.
- `ERR-TRANSFER-NOT-FOUND (u106)`: Escrow transfer does not exist.
- `ERR-TRANSFER-EXPIRED (u107)`: Escrow transfer has expired.
- `ERR-ALREADY-AUTHORIZED (u108)`: Notary is already authorized.
- `ERR-NOT-NOTARY (u109)`: Address is not an authorized notary.
- `ERR-TRANSFER-INCOMPLETE (u110)`: Transfer approvals are not completed.

## Functions

### Public Functions
- **register-property**: Registers a new property deed.
- **update-property-details**: Updates property information.
- **list-property-for-sale**: Lists a property for sale.
- **delist-property**: Removes a property from the market.
- **initiate-purchase**: Buyer initiates a property purchase, placing funds in escrow.
- **approve-transfer-as-seller**: Seller approves the transaction.
- **approve-transfer-as-notary**: Notary verifies and approves the transaction.
- **complete-transfer**: Finalizes the property transfer when all approvals are completed.
- **cancel-transfer**: Cancels an ongoing escrow transfer and refunds the buyer.
- **refund-expired-transfer**: Refunds buyers if an escrow transfer expires.
- **add-notary**: Adds an authorized notary (contract owner only).
- **deactivate-notary**: Removes a notary's authorization.
- **transfer-contract-ownership**: Transfers ownership of the contract to another principal.

### Read-Only Functions
- **get-property**: Retrieves details of a registered property.
- **is-property-owner**: Checks if an address owns a specified property.
- **get-escrow-details**: Retrieves escrow transaction details.
- **is-notary-active**: Checks if an address is an active notary.
- **get-notary-details**: Retrieves information about an authorized notary.

## Usage
1. **Register a Property**: Owners register properties with a unique ID.
2. **List for Sale**: Owners can list properties for sale with an asking price.
3. **Initiate Purchase**: Buyers initiate a purchase, locking funds in escrow.
4. **Approve Transfer**: Seller and notary approve the transaction.
5. **Complete Transfer**: Ownership is transferred when approvals are complete.

## Security Considerations
- **Notary Authorization**: Only contract owners can add/remove notaries.
- **Escrow Protection**: Funds are locked until conditions are met.
- **Transaction Expiration**: Expired transactions result in refunds.
- **Permission Controls**: Only owners and authorized parties can execute relevant functions.

## License
This smart contract is open-source and available for public use and modification under the MIT License.
