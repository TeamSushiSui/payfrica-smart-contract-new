module payfrica::savings;

use sui::{
    balance::{Self, Balance},
    coin::{Self, Coin,},
    table::{Table, new},
    dynamic_field as df,
    event
};

use payfrica::pool::{Self, Pool};
public struct Savings has key{
    id: UID,
    
    savings: u64,
    owner: address,    
}

public struct Valuts<phantom T> has key{
    id: UID,
    valuts: Balance<T>,
    owner: address,
    lock_time: u64,
    voter: Table<address, vector<u8>>,
}

public fun new_savings<T>(pool: &mut Pool,ctx: &mut TxContext){
    let savings = Savings{
        id: object::new(ctx),
        savings: balance::zero<T>(),
        owner: ctx.sender(),
    };

    transfer::transfer(savings, ctx.sender());
}
