# Photon Protocol Specification

## Overview
A protocol for managing token issuance and redemption systems with support for multiple applications, users, and redemption sinks. The protocol implements a three-registry system (Users, Applications, Tokens) with campaign management and redemption functionality.

## Core Components

### 1. Registry Systems

#### 1.1 User Registry
```
struct UserInfo {
    wallet_address: address,
    referrer_application_address: address,
    metadata: vector<u8>,  // JSON encoded user attributes
    registration_time: u64,
    is_active: bool
}

struct UserRegistry {
    users: Table<address, UserInfo>,
    total_users: u64
}
```

**Functions:**
- `register_user(wallet_address: address, referrer_app: address, metadata: vector<u8>)`
- `update_user_metadata(user: address, new_metadata: vector<u8>)`
- `deactivate_user(user: address)`
- `get_user_info(user: address): UserInfo`

#### 1.2 Application Registry
```
struct ApplicationInfo {
    name: String,
    address: address,
    workers: vector<address>,
    is_active: bool,
    created_at: u64
}

struct ApplicationRegistry {
    applications: Table<address, ApplicationInfo>,
    total_applications: u64
}
```

**Functions:**
- `register_application(name: String, app_address: address) : onlyAdmin`
- `add_worker(app_address: address, worker: address) : onlyAdmin`
- `remove_worker(app_address: address, worker: address) : onlyAdmin`
- `deactivate_application(app_address: address) : onlyAdmin`
- `is_valid_worker(app_address: address, worker: address): bool`

#### 1.3 Token Registry
```
struct TokenInfo {
    token_address: address,    // APT or USDC address
    is_active: bool,
    total_issued: u64,
    total_redeemed: u64
}

struct TokenRegistry {
    tokens: Table<address, TokenInfo>,
    supported_tokens: vector<address>
}
```

**Functions:**
- `add_supported_token(token_address: address) : onlyAdmin`
- `remove_supported_token(token_address: address) : onlyAdmin`
- `is_token_supported(token_address: address): bool`
- `update_token_stats(token_address: address, issued: u64, redeemed: u64)`

### 2. Campaign Management

```
struct Campaign {
    campaign_id: u64,
    application: address,
    token_address: address,
    token_quantity: u64,
    issued_balance: u64,
    redeemed_balance: Table<address, u64>,  // user -> quantity mapping
    is_active: bool,
    created_at: u64
}

struct CampaignRegistry {
    campaigns: Table<u64, Campaign>,
    campaign_counter: u64
}
```

**Functions:**
- `create_campaign(app_address: address, token: address, quantity: u64) : onlyApplication`
- `issue_tokens(campaign_id: u64, user: address, amount: u64) : onlyProtocolWorkers`
- `transfer_campaign_tokens(campaign_id: u64, to: address, amount: u64) : onlyCampaignCreator`
- `get_user_campaign_balance(campaign_id: u64, user: address): u64`

### 3. Redemption System

```
struct RedemptionSink {
    sink_id: u64,
    platform: String,           // e.g., "Google", "Apple", "Steam"
    min_quantity: u64,
    max_quantity: u64,
    quantity_multiples: vector<u64>,
    is_active: bool
}

struct RedemptionRegistry {
    sinks: Table<u64, RedemptionSink>,
    sink_counter: u64,
    redemption_history: Table<vector<u8>, RedemptionRecord>  // UUID -> Record
}

struct RedemptionRecord {
    uuid: vector<u8>,
    user: address,
    sink_id: u64,
    quantity: u64,
    status: u8,
    created_at: u64
}
```

**Functions:**
- `create_redemption_sink(platform: String, min_qty: u64, max_qty: u64, multiples: vector<u64>) : onlyAdmin`
- `update_sink_limits(sink_id: u64, new_min: u64, new_max: u64) : onlyAdmin`
- `deactivate_sink(sink_id: u64) : onlyAdmin`
- `redeem_tokens(sink_id: u64, quantity: u64) : onlyUser`
- `process_redemption(uuid: vector<u8>) : onlyAdmin`

### 4. Access Control

```
struct ProtocolRoles {
    admin: address,
    workers: Table<address, bool>,
    pending_admin: Option<address>
}
```

**Functions:**
- `initialize_protocol(admin: address)`
- `add_protocol_worker(worker: address) : onlyAdmin`
- `remove_protocol_worker(worker: address) : onlyAdmin`
- `transfer_admin_role(new_admin: address) : onlyAdmin`
- `accept_admin_role() : onlyPendingAdmin`

## Core Operations

### Token Issuance Flow
1. Admin creates application in Application Registry
2. Application creates campaign with token specifications
3. Protocol workers can issue tokens to users within campaign limits
4. Campaign creator can transfer tokens within campaign

### Token Redemption Flow
1. Admin creates redemption sinks with platform details
2. User requests redemption with sink_id and quantity
3. System validates:
   - User has sufficient balance
   - Quantity meets sink's min/max limits
   - Quantity is valid multiple
4. System generates UUID and creates redemption record
5. Admin processes redemption and transfers tokens

## Events

```
struct Events {
    user_registered: Event<UserRegisteredEvent>,
    application_added: Event<ApplicationAddedEvent>,
    campaign_created: Event<CampaignCreatedEvent>,
    tokens_issued: Event<TokensIssuedEvent>,
    redemption_requested: Event<RedemptionRequestedEvent>,
    redemption_processed: Event<RedemptionProcessedEvent>
}
```

## Error Codes

```
const ERR_INSUFFICIENT_BALANCE: u64 = 1;
const ERR_INVALID_QUANTITY: u64 = 2;
const ERR_SINK_INACTIVE: u64 = 3;
const ERR_UNAUTHORIZED: u64 = 4;
const ERR_CAMPAIGN_INACTIVE: u64 = 5;
```
