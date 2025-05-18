module payfrica::send;
use sui::{
    clock::Clock,
    event,
    coin::{Coin},
};
use std::{
    string::String,
    type_name::{Self, TypeName}
};

use suins::{ 
    suins::SuiNS,
    registry::Registry,
    domain
};
const ENameNotFound: u64 = 0;
const ENameNotPointingToAddress: u64 = 1;
// const ENameExpired: u64 = 2;

public struct CoinTransferAddressEvent has copy, drop{
    coin_type: TypeName,
    amount: u64,
    recipient: address,
    sender: address,
    time: u64
}

public struct CoinTranferNsEvent has copy, drop{
    coin_type: TypeName,
    amount: u64,
    recipient: String,
    sender: address,
    time: u64
}

public fun send_ns<T>(coin: Coin<T>, suins: &SuiNS, name: String, clock: &Clock, ctx: &mut TxContext){
    //  Look up the name on the registry.
    let mut optional = suins.registry<Registry>().lookup(domain::new(name));
    // Check that the name indeed exists.
    assert!(optional.is_some(), ENameNotFound);

    let name_record = optional.extract();
    // Check that name has not expired. 
    // This check is optional, but it's recommended you perform the verification.
    // assert!(!name_record.has_expired(clock), ENameExpired);
    // Check that the name has a target address set.
    assert!(name_record.target_address().is_some(), ENameNotPointingToAddress);

    // Transfer the object to that name.
    event::emit(
        CoinTranferNsEvent{
            coin_type: type_name::get<T>(),
            amount: coin.value(),
            recipient: name,
            sender: ctx.sender(),
            time: clock.timestamp_ms()
        }
    );
    transfer::public_transfer(coin, name_record.target_address().extract())
}

public fun send_coin_address<T>(coin: Coin<T>, recipient: address, clock: &Clock, ctx: &mut TxContext){
    event::emit(
        CoinTransferAddressEvent{
            coin_type: type_name::get<T>(),
            amount: coin.value(),
            recipient,
            sender: ctx.sender(),
            time: clock.timestamp_ms()
        }
    );
    transfer::public_transfer(coin, recipient);
}