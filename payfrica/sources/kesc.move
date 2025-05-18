module payfrica::kesc;
use sui::{
    coin::{Self, Coin, TreasuryCap},
    url::{Self, Url},
};
use payfrica::pool::{
    Pool
};

public struct KESC has drop{}

fun init(witness: KESC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"KESC", 
        b"KESC", 
        b"KESC is a Kenyan shilling stable coin issued by payfrica. KESC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money on payfica", 
        option::some<Url>(url::new_unsafe_from_bytes(b"https://i.ibb.co/KxctQq8b/photo-2025-03-22-10-21-02.jpg")), 
        ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}

public fun mint_to_pool(
    pool: &mut Pool<KESC>,
    treasury_cap: &mut TreasuryCap<KESC>,
    amount: u64,
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    pool.add_mint(coin);
}

public fun burn(treasury_cap: &mut TreasuryCap<KESC>, coin: Coin<KESC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(KESC{} , ctx);
}

