module stan::coin {
    use std::signer;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::fungible_asset::{Self, Metadata, MintRef, BurnRef, TransferRef};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;

    // Events
    #[event]
    struct CreateFAEvent has store, drop {
        creator_addr: address,
        fa_obj: Object<Metadata>,
        max_supply: Option<u128>,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
    }

    #[event]
    struct MintEvent has store, drop {
        fa_obj: Object<Metadata>,
        user: address,
        amount: u64,
    }

    #[event]
    struct BurnEvent has store, drop {
        fa_obj: Object<Metadata>,
        user: address,
        amount: u64,
    }

    /// Error codes
    const ERR_NOT_AUTHORIZED: u64 = 1;

    /// Constants
    const ICON_URL: vector<u8> = b"https://img.freepik.com/free-psd/gleaming-gold-coin-wealth-prosperity-fortune_84443-32188.jpg";
    const PROJECT_URL: vector<u8> = b"https://www.stan/";
    /// Structs
    struct FungibleAssetStore has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    struct Registry has key {
        fa_objects: vector<Object<Metadata>>,
    }

    fun init_module(sender: &signer) {
        move_to(sender, Registry {
            fa_objects: vector::empty()
        });
    }

    public fun create_fa(
        account: &signer,
        token_name: String,
        token_symbol: String,
        decimals: u8,
        max_supply: Option<u128>,
    ): Object<Metadata> acquires Registry {
        let account_addr = signer::address_of(account);
        //assert!(auth::is_authorized(account_addr), ERR_NOT_AUTHORIZED);
        
        let constructor_ref = &object::create_sticky_object(account_addr);
        let fa_object_signer = object::generate_signer(constructor_ref);
        
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            max_supply,
            token_name,
            token_symbol,
            decimals,
            string::utf8(ICON_URL),
            string::utf8(PROJECT_URL)
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        
        let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);

        move_to(&fa_object_signer, FungibleAssetStore {
            mint_ref,
            burn_ref,
            transfer_ref,
        });

        // Add to registry
        let registry = borrow_global_mut<Registry>(@stan);
        vector::push_back(&mut registry.fa_objects, metadata);

        // Emit creation event
        event::emit(CreateFAEvent {
            creator_addr: account_addr,
            fa_obj: metadata,
            max_supply,
            name: token_name,
            symbol: token_symbol,
            decimals,
            icon_uri: string::utf8(ICON_URL),
            project_uri: string::utf8(PROJECT_URL),
        });

        metadata
    }

    public fun mint(
        account: &signer,
        fa_obj: Object<Metadata>,
        amount: u64
    ) acquires FungibleAssetStore {
        let sender = signer::address_of(account);
        //assert!(auth::is_authorized(sender), ERR_NOT_AUTHORIZED);
        let fa_store = borrow_global<FungibleAssetStore>(object::object_address(&fa_obj));
        primary_fungible_store::mint(&fa_store.mint_ref, sender, amount);

        event::emit(MintEvent {
            fa_obj,
            user:sender,
            amount:amount,
        });
    }

    public fun burn(
        token_owner: &signer,
        fa_obj: Object<Metadata>,
        amount: u64
    ) acquires FungibleAssetStore {
        let sender = signer::address_of(token_owner);
        //assert!(auth::is_authorized(sender), ERR_NOT_AUTHORIZED);
        let fa_store = borrow_global<FungibleAssetStore>(object::object_address(&fa_obj));
        primary_fungible_store::burn(&fa_store.burn_ref, sender, amount);

        event::emit(BurnEvent {
            fa_obj,
            user: sender,
            amount:amount,
        });
    }

    // ================================= View Functions ================================== //

    #[view]
    public fun get_registry(): vector<Object<Metadata>> acquires Registry {
        let registry = borrow_global<Registry>(@stan);
        registry.fa_objects
    }

    #[view]
    public fun total_supply(fa_obj: Object<Metadata>): u64 {
        let supply_opt = fungible_asset::supply(fa_obj);
        if (option::is_some(&supply_opt)) {
            (option::extract(&mut supply_opt) as u64)
        } else {
            0
        }
    }

    #[view]
    public fun balance_of(fa_obj: Object<Metadata>, addr: address): u64 {
        primary_fungible_store::balance(addr, fa_obj)
    }
}