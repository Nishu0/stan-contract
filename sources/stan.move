module stan::game_rewards {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::Metadata;
    use stan::coin::{Self, FungibleAssetStore};
    use std::vector;

    // Error codes
    const ERR_USER_NOT_REGISTERED: u64 = 1;
    const ERR_INSUFFICIENT_BALANCE: u64 = 2;
    const ERR_INVALID_NONCE: u64 = 3;

    // Enums represented as constants for actions
    const ACTION_GAME_WON: u8 = 1;
    const ACTION_DEFEATED_BOSS: u8 = 2;

    // Enums for game types
    const GAME_TYPE_BATTLE_ROYALE: u8 = 1;
    const GAME_TYPE_PLAYER_VS_PLAYER: u8 = 2;

    // Enums for redemption types
    const REDEMPTION_GOOGLE_CREDIT: u8 = 1;
    const REDEMPTION_APPLE_CREDIT: u8 = 2;

    // Structs
    struct UserRegistry has key {
        users: vector<User>,
        stan_token: Object<Metadata>,
    }

    struct User has store, drop {
        user_id: String,
        wallet_address: address,
        name: String,
    }

    struct RedemptionRecord has store {
        nonce: u64,
        sink: String,
        amount: u64,
        redemption_type: u8,
    }

    fun init_module(sender: &signer) {
        // Create STAN token
        let stan_token = coin::create_fa(
            sender,
            string::utf8(b"STAN Token"),
            string::utf8(b"STAN"),
            8, // decimals
            std::option::none(), // no max supply
        );

        // Initialize user registry
        move_to(sender, UserRegistry {
            users: vector::empty(),
            stan_token,
        });
    }

    public entry fun register_user(
        account: &signer,
        user_id: String,
        name: String,
    ) acquires UserRegistry {
        let registry = borrow_global_mut<UserRegistry>(@stan);
        let wallet_address = signer::address_of(account);
        
        // Check if user already exists
        let i = 0;
        let len = vector::length(&registry.users);
        while (i < len) {
            let user = vector::borrow(&registry.users, i);
            assert!(user.wallet_address != wallet_address, 0);
            i = i + 1;
        };

        let new_user = User {
            user_id,
            wallet_address,
            name,
        };
        vector::push_back(&mut registry.users, new_user);
    }

    public entry fun mint_reward(
        account: &signer,
        action: u8,
        game_type: u8,
        amount: u64
    ) acquires UserRegistry {
        let registry = borrow_global<UserRegistry>(@stan);
        let wallet_address = signer::address_of(account);
        
        // Verify user is registered
        let is_registered = false;
        let i = 0;
        let len = vector::length(&registry.users);
        while (i < len) {
            let user = vector::borrow(&registry.users, i);
            if (user.wallet_address == wallet_address) {
                is_registered = true;
                break
            };
            i = i + 1;
        };
        assert!(is_registered, ERR_USER_NOT_REGISTERED);

        // Validate action and game type
        assert!(
            action == ACTION_GAME_WON || action == ACTION_DEFEATED_BOSS,
            0
        );
        assert!(
            game_type == GAME_TYPE_BATTLE_ROYALE || game_type == GAME_TYPE_PLAYER_VS_PLAYER,
            0
        );

        // Mint tokens
        coin::mint(account, registry.stan_token, amount);
    }

    public entry fun redeem_tokens(
        account: &signer,
        amount: u64,
        redemption_type: u8,
        nonce: u64,
        sink: String
    ) acquires UserRegistry {
        let registry = borrow_global<UserRegistry>(@stan);
        let wallet_address = signer::address_of(account);

        // Verify user is registered
        let is_registered = false;
        let i = 0;
        let len = vector::length(&registry.users);
        while (i < len) {
            let user = vector::borrow(&registry.users, i);
            if (user.wallet_address == wallet_address) {
                is_registered = true;
                break
            };
            i = i + 1;
        };
        assert!(is_registered, ERR_USER_NOT_REGISTERED);

        // Check balance
        let balance = coin::balance_of(registry.stan_token, wallet_address);
        assert!(balance >= amount, ERR_INSUFFICIENT_BALANCE);

        // Validate redemption type
        assert!(
            redemption_type == REDEMPTION_GOOGLE_CREDIT || 
            redemption_type == REDEMPTION_APPLE_CREDIT,
            0
        );

        // Burn tokens
        coin::burn(account, registry.stan_token, amount);
    }

    #[view]
    public fun is_registered(addr: address): bool acquires UserRegistry {
        let registry = borrow_global<UserRegistry>(@stan);
        let i = 0;
        let len = vector::length(&registry.users);
        while (i < len) {
            let user = vector::borrow(&registry.users, i);
            if (user.wallet_address == addr) {
                return true
            };
            i = i + 1;
        };
        false
    }
}
