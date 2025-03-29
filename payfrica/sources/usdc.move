module payfrica::usdc;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::url::{Self, Url};

public struct USDC has drop{}

fun init(witness: USDC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        6, 
        b"USDC", 
        b"USDC", 
        b"USDC is a US dollar-backed stablecoin issued by Circle. USDC is designed to provide a faster, safer, and more efficient way to send, spend, and exchange money around the world.", 
        option::some<Url>(url::new_unsafe_from_bytes(b"https://strapi-dev.scand.app/uploads/usdc_03b37ed889.png")), 
        ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender())
}

public fun mint(
    treasury_cap: &mut TreasuryCap<USDC>, 
    amount: u64, 
    recipient: address, 
    ctx: &mut TxContext,
) {
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient)
}

public fun burn(treasury_cap: &mut TreasuryCap<USDC>, coin: Coin<USDC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun call_init(ctx: &mut TxContext) {
    init(USDC{} , ctx);
}

