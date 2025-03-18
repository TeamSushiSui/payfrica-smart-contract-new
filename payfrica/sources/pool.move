module payfrica::pool{
    use sui::{
        balance::{Self, Balance},
        coin::{Self, Coin,},
        table::{Table, new},
        dynamic_field as df,
        event
    };
    use std::{
        // string::String,
        type_name::{Self, TypeName}
    };
    use payfrica::ngnc::NGNC;

    public struct Pool<phantom NGNC, phantom T1> has store, key{
        id: UID,
        coin_a: Balance<NGNC>,
        coin_b: Balance<T1>,
    }

    public struct Providers has store{
        coin_a_liquidity_providers: Table<address, u64>,
        coin_b_liquidity_providers: Table<address, u64>,
    }

    public struct PoolCreated has copy, drop{
        pool_id: ID,
        coin_a_type: TypeName,
        coin_b_type: TypeName,
    }

    public struct SwapCreated has copy, drop{
        pool_id: ID,
        conversio_rate: u64,
        input_coin_type: TypeName,
        output_coin_type: TypeName,
        input_coin_amount: u64,
        output_coin_amount: u64,
    }

    public struct PoolLiquidityInteraction has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        amount: u64,
        add_liquidty: bool,
    }

    public struct SinglePool<phantom T> has store, key{
        id: UID,
        coin_a: Balance<T>,
    }

    public struct SingleProviders has store{
        liquidity_providers: Table<address, u64>,
    }

    public fun new_pool<NGNC, T1>(ctx: &mut TxContext){
        let mut pool = Pool{
            id: object::new(ctx),
            coin_a: balance::zero<NGNC>(),
            coin_b: balance::zero<T1>(),
        };

        let providers = Providers{
            coin_a_liquidity_providers: new<address, u64>(ctx),
            coin_b_liquidity_providers: new<address, u64>(ctx),
        };
        df::add(&mut pool.id, b"providers", providers);
        let pool_id =  pool.id.as_inner();
        transfer::public_share_object(pool);
        event::emit(PoolCreated{ 
            pool_id: *pool_id,
            coin_a_type: type_name::get<NGNC>(),
            coin_b_type: type_name::get<T1>(),
        });
    }

    public fun new_single_pool<T>(ctx: &mut TxContext){
        let mut pool = SinglePool{
            id: object::new(ctx),
            coin_a: balance::zero<T>(),
        };

        let providers = SingleProviders{
            liquidity_providers: new<address, u64>(ctx),
        };

        df::add(&mut pool.id, b"providers", providers);

        transfer::public_share_object(pool);
    }

    public fun add_liquidity_single_pool<T>(pool: &mut SinglePool<T>, liquidity_coin: Coin<T>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, 0);
        let providers: &mut SingleProviders = df::borrow_mut(&mut pool.id, b"providers");
        if (providers.liquidity_providers.contains(sender)){
            let current_amount = providers.liquidity_providers.borrow_mut(sender);
            *current_amount = *current_amount + amount;
        } else{
            providers.liquidity_providers.add(sender, amount);
        };
        let coin_balance : Balance<T> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_a, coin_balance);
    }

    #[allow(lint(self_transfer))]
    public fun remove_liduidity_single_pool<T>(pool: &mut SinglePool<T>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        let providers: &mut SingleProviders = df::borrow_mut(&mut pool.id, b"providers");
        assert!(providers.liquidity_providers.contains(sender), 0);
        let liquidity_value = providers.liquidity_providers.borrow_mut(sender);
        assert!(amount <= *liquidity_value, 0);
        if (amount == *liquidity_value){
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            providers.liquidity_providers.remove(sender);
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            *liquidity_value = *liquidity_value - amount;
            transfer::public_transfer(liquidity_coin, sender);
        };
    }

    public fun add_liquidity_a<NGNC, T1>(pool: &mut Pool<NGNC, T1>, liquidity_coin: Coin<NGNC>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, 0);
        let providers: &mut Providers = df::borrow_mut(&mut pool.id, b"providers");
        if (providers.coin_a_liquidity_providers.contains(sender)){
            let current_amount = providers.coin_a_liquidity_providers.borrow_mut(sender);
            *current_amount = *current_amount + amount;
        } else{
            providers.coin_a_liquidity_providers.add(sender, amount);
        };
        let coin_balance : Balance<NGNC> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_a, coin_balance);

        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<NGNC>(),
            amount,
            add_liquidty: true,
        });
    }

    public fun add_liquidity_b<NGNC, T1>(pool: &mut Pool<NGNC, T1>, liquidity_coin: Coin<T1>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, 0);
        let providers: &mut Providers = df::borrow_mut(&mut pool.id, b"providers");
        if (providers.coin_b_liquidity_providers.contains(sender)){
            let current_amount = providers.coin_b_liquidity_providers.borrow_mut(sender);
            *current_amount = *current_amount + amount;
        } else{
            providers.coin_b_liquidity_providers.add(sender, amount);
        };
        let coin_balance : Balance<T1> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_b, coin_balance);
        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T1>(),
            amount,
            add_liquidty: true,
        });
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_a<NGNC, T1>(pool: &mut Pool<NGNC, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        let providers: &mut Providers = df::borrow_mut(&mut pool.id, b"providers");
        assert!(providers.coin_a_liquidity_providers.contains(sender), 0);
        let liquidity_value = providers.coin_a_liquidity_providers.borrow_mut(sender);
        assert!(amount <= *liquidity_value, 0);
        if (amount == *liquidity_value){
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            providers.coin_a_liquidity_providers.remove(sender);
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            *liquidity_value = *liquidity_value - amount;
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<NGNC>(),
            amount,
            add_liquidty: false,
        });
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_b<NGNC, T1>(pool: &mut Pool<NGNC, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        let providers: &mut Providers = df::borrow_mut(&mut pool.id, b"providers");
        assert!(providers.coin_b_liquidity_providers.contains(sender), 0);
        let liquidity_value = providers.coin_b_liquidity_providers.borrow_mut(sender);
        assert!(amount <= *liquidity_value, 0);
        if (amount == *liquidity_value){
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            providers.coin_b_liquidity_providers.remove(sender);
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            *liquidity_value = *liquidity_value - amount;
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T1>(),
            amount,
            add_liquidty: false,
        });

    }

    #[allow(lint(self_transfer))]
    public fun convert_a_to_b<NGNC, T1>(pool: &mut Pool<NGNC, T1>, conversion_coin: Coin<NGNC>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(conversion_coin.value() > 0, 0);
        let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
        let coin_b_scale_factor = 10u64.pow(coin_b_decimals);
        let amount = (conversion_coin.value() * coin_b_scale_factor) / (conversio_rate * coin_a_scale_factor);
        let coin_balance : Balance<NGNC> = conversion_coin.into_balance();
        assert!(amount <= pool.coin_b.value(), 0);
        balance::join(&mut pool.coin_a, coin_balance);
        let b_coin = coin::take(&mut pool.coin_b, amount, ctx);
        transfer::public_transfer(b_coin, sender);
        event::emit(SwapCreated{
            pool_id: *pool.id.as_inner(),
            conversio_rate,
            input_coin_type: type_name::get<NGNC>(),
            output_coin_type: type_name::get<T1>(),
            input_coin_amount: conversion_coin.value(),
            output_coin_amount: amount,
        });
    }

    #[allow(lint(self_transfer))]
    public fun convert_b_to_a<NGNC, T1>(pool: &mut Pool<NGNC, T1>, conversion_coin: Coin<T1>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(conversion_coin.value() > 0, 0);
        let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
        let coin_b_scale_factor = 10u64.pow(coin_b_decimals);
        let amount = ((conversion_coin.value() * conversio_rate) / coin_b_scale_factor) * coin_a_scale_factor;
        let coin_balance : Balance<T1> = conversion_coin.into_balance();
        assert!(amount <= pool.coin_a.value(), 0);
        balance::join(&mut pool.coin_b, coin_balance);
        let a_coin = coin::take(&mut pool.coin_a, amount, ctx);
        transfer::public_transfer(a_coin, sender);
        event::emit(SwapCreated{
            pool_id: *pool.id.as_inner(),
            conversio_rate,
            input_coin_type: type_name::get<T1>(),
            output_coin_type: type_name::get<NGNC>(),
            input_coin_amount: conversion_coin.value(),
            output_coin_amount: amount,
        });
    }

    public fun get_pool_id<NGNC, T1>(pool: &Pool<NGNC, T1>) :ID{
        *pool.id.as_inner()
    }
}
