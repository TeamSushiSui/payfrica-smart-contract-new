module payfrica::ngnc;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::url::{Self, Url};

public struct NGNC has drop{}

fun init(witness: NGNC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"NGNC", 
        b"NGNC", 
        b"NGNC is a Naira stable coin issued by payfrica. NGNC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money", 
        option::some<Url>(url::new_unsafe_from_bytes(b"https://i.ibb.co/1LZXjZW/e-naira-logo.png")), 
        ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}

public fun mint(
    treasury_cap: &mut TreasuryCap<NGNC>, 
    amount: u64, 
    recipient: address, 
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient)
}

public fun burn(treasury_cap: &mut TreasuryCap<NGNC>, coin: Coin<NGNC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(NGNC{} , ctx);
}

