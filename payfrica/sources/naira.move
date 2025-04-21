module payfrica::ngnc;
use sui::{
    coin::{Self, Coin, TreasuryCap},
    url::{Self, Url},
    balance::{Self, Balance},
};

use payfrica::pool_new::{
    Pool
};

const EInvalidCoinValue: u64 = 0x1;
public struct NGNC has drop{}

public struct Reserve<phantom USDC> has key, store{
    id: UID,
    balance: Balance<USDC>, // USDC held as backing
    total_ngnc_token_supply: u64,
}

fun init(witness: NGNC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"NGNC", 
        b"NGNC", 
        b"NGNC is a Naira stable coin issued by payfrica. NGNC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money on payfica", 
        option::some<Url>(url::new_unsafe_from_bytes(b"https://i.ibb.co/KxctQq8b/photo-2025-03-22-10-21-02.jpg")), 
        ctx);

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}

public fun create_reserve<USDC>(ctx: &mut TxContext) {
    let reserve = Reserve {
        id: object::new(ctx),
        balance: balance::zero<USDC>(),
        total_ngnc_token_supply: 0,
    };
    transfer::share_object(reserve);
}

public fun mint_to_pool<USDC>(
    reserve: &mut Reserve<USDC>,
    pool: &mut Pool<NGNC>,
    reserve_coin: Coin<USDC>,
    treasury_cap: &mut TreasuryCap<NGNC>,
    conversion_rate: u64,
    scale_decimal: u8,
    ctx: &mut TxContext,
) {
    let coin_value = reserve_coin.value(); 
    assert!(coin_value > 0, EInvalidCoinValue);
    let scale_factor = 10u64.pow(scale_decimal);
    let amount = ((coin_value * conversion_rate) / scale_factor);
    reserve.balance.join(reserve_coin.into_balance());
    let coin = coin::mint(treasury_cap, amount, ctx);
    pool.add_mint(coin, ctx);
}

public fun burn(treasury_cap: &mut TreasuryCap<NGNC>, coin: Coin<NGNC>) {
    coin::burn(treasury_cap, coin);
}


#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(NGNC{} , ctx);
}

