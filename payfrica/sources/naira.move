module payfrica::ngnc;
use sui::{
    coin::{Self, Coin, TreasuryCap},
    url::{Self, Url},
};
use payfrica::pool::{
    Pool
};

public struct NGNC has drop{}


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

public fun mint_to_pool(
    pool: &mut Pool<NGNC>,
    treasury_cap: &mut TreasuryCap<NGNC>,
    amount: u64,
    ctx: &mut TxContext,
) {
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

