module payfrica::ghsc;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::url::{Self, Url};

public struct GHSC has drop{}

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

public fun mint(
    treasury_cap: &mut TreasuryCap<GHSC>, 
    amount: u64, 
    recipient: address, 
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient)
}

public fun burn(treasury_cap: &mut TreasuryCap<GHSC>, coin: Coin<GHSC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(GHSC{} , ctx);
}

