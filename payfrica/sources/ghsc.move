module payfrica::ghsc;
use sui::{
    coin::{Self, Coin, TreasuryCap},
    url::{Self, Url},
    balance::{Self, Balance},
};
use std::type_name::{Self, TypeName};
use payfrica::pool::{
    Pool
};

const EInvalidCoinValue: u64 = 0x1;

public struct GHSC has drop{}

public struct Reserve<phantom USDC> has key, store{
    id: UID,
    balance: Balance<USDC>, // USDC held as backing
    reserve_type: TypeName,
    total_ghsc_token_supply: u64,
}

public fun create_reserve<GHSC,USDC>(ctx: &mut TxContext) {
    let reserve = Reserve {
        id: object::new(ctx),
        balance: balance::zero<USDC>(),
        reserve_type: type_name::get<GHSC>(),
        total_ghsc_token_supply: 0,
    };
    transfer::share_object(reserve);
}

fun init(witness: GHSC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"GHSC", 
        b"GHSC", 
        b"GHSC is a Cedi stable coin issued by payfrica. GHSC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money on payfrica", 
        option::some<Url>(url::new_unsafe_from_bytes(b"https://t4.ftcdn.net/jpg/11/63/48/97/240_F_1163489755_Gu6ylU7fKQ3011TFVJ1aeJ8gbUW3gSil.jpg")), 
        ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}

public fun mint_to_pool<USDC>(
    reserve: &mut Reserve<USDC>,
    pool: &mut Pool<GHSC>,
    reserve_coin: Coin<USDC>,
    treasury_cap: &mut TreasuryCap<GHSC>,
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

public fun burn(treasury_cap: &mut TreasuryCap<GHSC>, coin: Coin<GHSC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(GHSC{} , ctx);
}