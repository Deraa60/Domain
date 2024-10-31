# Domain Registration Smart Contract

A decentralized domain name registration and management system built on the Stacks blockchain using Clarity smart contracts. This contract enables users to register, manage, transfer, and configure domain names in a secure and decentralized manner.

## Features

- Secure domain registration with preorder-reveal pattern
- Domain transfers between users
- Automatic expiration handling
- Domain renewal system
- Custom domain records management
- Resolver configuration
- Efficient name availability checking

## Contract Details

### Registration Process

The domain registration process consists of two steps to prevent front-running:

1. **Preorder Phase**
   ```clarity
   (preorder-domain (hashed-domain-name (buff 32)) (payment-amount-ustx uint))
   ```
   - Hash your domain name with a secret salt
   - Submit the hash and registration fee
   - Fee is burned as part of registration

2. **Registration Phase**
   ```clarity
   (register-domain (domain-name (string-ascii 64)) (preorder-salt (buff 32)))
   ```
   - Reveal the actual domain name and salt
   - Contract verifies the hash matches preorder
   - Domain is registered if available

### Domain Management

#### Transfer Ownership
```clarity
(transfer-domain (domain-name (string-ascii 64)) (new-domain-owner principal))
```
- Transfer domain to a new owner
- Only current owner can initiate
- Domain must not be expired

#### Renew Registration
```clarity
(renew-domain-registration (domain-name (string-ascii 64)))
```
- Extend domain registration by 1 year (52,560 blocks)
- Requires payment of registration fee
- Can be done by domain owner

#### Set Resolver
```clarity
(set-domain-resolver (domain-name (string-ascii 64)) (new-resolver (optional principal)))
```
- Configure resolver for the domain
- Optional: Set to 'none' to clear resolver

#### Manage Records
```clarity
(set-domain-record (domain-name (string-ascii 64)) (record-key (string-ascii 128)) (record-value (string-ascii 256)))
```
- Store custom records for the domain
- Key-value pairs for configuration

### Reading Domain Information

#### Check Availability
```clarity
(is-domain-name-available (domain-name (string-ascii 64)))
```
- Returns boolean indicating if domain can be registered

#### Get Domain Details
```clarity
(get-domain-details (domain-name (string-ascii 64)))
```
- Returns full domain information including:
  - Owner
  - Expiration block
  - Resolver
  - Registration block
  - Name hash

#### Get Domain Records
```clarity
(get-domain-record (domain-name (string-ascii 64)) (record-key (string-ascii 128)))
```
- Retrieve specific domain record value

#### Check Expiration
```clarity
(get-domain-expiration (domain-name (string-ascii 64)))
```
- Returns the block height when domain expires

## Configuration Constants

| Constant | Value | Description |
|----------|--------|-------------|
| DOMAIN-REGISTRATION-PERIOD-BLOCKS | 52,560 | Registration period (~1 year) |
| MINIMUM-DOMAIN-NAME-LENGTH | 3 | Minimum characters in domain name |
| MAXIMUM-DOMAIN-NAME-LENGTH | 63 | Maximum characters in domain name |
| DOMAIN-REGISTRATION-FEE-STX | 100,000 | Registration fee in microSTX |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| ERROR-DOMAIN-ALREADY-REGISTERED | u100 | Domain name is taken |
| ERROR-NOT-AUTHORIZED | u101 | Caller not authorized |
| ERROR-DOMAIN-NOT-REGISTERED | u102 | Domain doesn't exist |
| ERROR-INVALID-DOMAIN-NAME | u103 | Name length requirements not met |
| ERROR-DOMAIN-EXPIRED | u104 | Domain has expired |
| ERROR-INSUFFICIENT-PAYMENT | u105 | Registration fee not met |

## Security Considerations

1. **Registration Process**
   - Always use a random salt for preorder
   - Keep salt secret until reveal
   - Verify transaction confirmation before reveal

2. **Domain Management**
   - Check domain expiration before transactions
   - Verify ownership before transfers
   - Maintain secure key management

3. **Financial**
   - Registration fees are burned
   - Ensure sufficient balance for operations
   - No refunds for failed registrations

## Best Practices

1. **Domain Names**
   - Use lowercase ASCII characters
   - Avoid special characters
   - Verify length requirements

2. **Records Management**
   - Use consistent key naming
   - Keep records updated
   - Remove unnecessary records

3. **Renewal**
   - Monitor expiration dates
   - Renew well before expiration
   - Maintain sufficient STX balance