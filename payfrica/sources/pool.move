module payfrica::pool{
    use sui::{
        balance::{Self, Balance},
        coin::{Self, Coin,},
        table::{Self,Table, new},
        bag::{Self, Bag},
        dynamic_field as df,
        event
    };
    use std::{
        // string::String,
        type_name::{Self, TypeName}
    };

    public struct PayfricaPool has key{
        id: UID,
        tokens: vector<TypeName>,
        rewards: Bag,
    }

    public struct POOL has drop {}

    public struct Pool<phantom T0, phantom T1> has store, key{
        id: UID,
        coin_a: Balance<T0>,
        coin_b: Balance<T1>,
        coin_a_rewards: Balance<T0>,
        coin_b_rewards: Balance<T1>,
        coin_a_liquidity_providers: Table<address, Providers<T0>>,
        coin_b_liquidity_providers: Table<address, Providers<T1>>,
        coin_a_liquidity_providers_list: vector<address>,
        coin_b_liquidity_providers_list: vector<address>,
    }

    public struct Providers<phantom T> has store{
        amount: u64,
        rewards: Balance<T>,
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

    fun init(otw: POOL,ctx: &mut TxContext){
        let pool: PayfricaPool = PayfricaPool{
            id: object::new(ctx),
            tokens: vector::empty<TypeName>(),
            rewards: bag::new(ctx),
        };

        transfer::share_object(pool);
    }

    public fun new_pool<T0, T1>(ctx: &mut TxContext){
        let mut pool = Pool{
            id: object::new(ctx),
            coin_a: balance::zero<T0>(),
            coin_b: balance::zero<T1>(),
            coin_a_rewards: balance::zero<T0>(),
            coin_b_rewards: balance::zero<T1>(),
            coin_a_liquidity_providers: new<address, Providers<T0>>(ctx),
            coin_b_liquidity_providers: new<address, Providers<T1>>(ctx),
            coin_a_liquidity_providers_list: vector::empty<address>(),
            coin_b_liquidity_providers_list: vector::empty<address>(),
        };

        let pool_id =  pool.id.as_inner();
        transfer::public_share_object(pool);
        event::emit(PoolCreated{ 
            pool_id: *pool_id,
            coin_a_type: type_name::get<T0>(),
            coin_b_type: type_name::get<T1>(),
        }); 
    }

    public fun add_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, liquidity_coin: Coin<T0>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, 0);
        spilt_rewards_a(pool, payfrica_pool, ctx);
        if (pool.coin_a_liquidity_providers.contains(sender)){
            let current_amount = pool.coin_a_liquidity_providers.borrow_mut(sender).amount;
            current_amount = current_amount + amount;
        } else{
            let providers = Providers<T0>{
                amount,
                rewards: balance::zero<T0>()
            };
            pool.coin_a_liquidity_providers.add(sender, providers);
        };
        let coin_balance : Balance<T0> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_a, coin_balance);

        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            add_liquidty: true,
        });
    }

    public fun add_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, liquidity_coin: Coin<T1>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, 0);
        spilt_rewards_b(pool, payfrica_pool, ctx);
        if (pool.coin_b_liquidity_providers.contains(sender)){
            let current_amount = pool.coin_b_liquidity_providers.borrow_mut(sender).amount;
            current_amount = current_amount + amount;
        } else{
            let providers = Providers<T1>{
                amount,
                rewards: balance::zero<T1>()
            };
            pool.coin_b_liquidity_providers.add(sender, providers);
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
    public fun remove_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(pool.coin_a_liquidity_providers.contains(sender), 0);
        let liquidity_provider = pool.coin_a_liquidity_providers.borrow_mut(sender);
        assert!(amount <= liquidity_provider.amount, 0);
        if (amount == liquidity_provider.amount){
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            claim_rewards_a(pool, ctx);
            remove_address_from_list(pool.coin_a_liquidity_providers_list, sender);
            let provider = pool.coin_a_liquidity_providers.remove(sender);
            let Providers{ amount: _, rewards} = provider;
            rewards.destroy_zero();
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            claim_rewards_a(pool, ctx);
            liquidity_provider.amount = liquidity_provider.amount - amount;
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            add_liquidty: false,
        });
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(pool.coin_b_liquidity_providers.contains(sender), 0);
        let liquidity_provider = pool.coin_b_liquidity_providers.borrow_mut(sender);
        assert!(amount <= liquidity_provider.amount, 0);
        if (amount == liquidity_provider.amount){
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            claim_rewards_b(pool, ctx);
            remove_address_from_list(pool.coin_b_liquidity_providers_list, sender);
            let provider = pool.coin_b_liquidity_providers.remove(sender);
            let Providers{ amount: _, rewards} = provider;
            rewards.destroy_zero();
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            claim_rewards_b(pool, ctx);
            liquidity_provider.amount = liquidity_provider.amount - amount;
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(PoolLiquidityInteraction{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            add_liquidty: false,
        });
    }

    #[allow(lint(self_transfer))]
    public fun convert_a_to_b<T0, T1>(pool: &mut Pool<T0, T1>, conversion_coin: Coin<T0>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(conversion_coin.value() > 0, 0);
        let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
        let coin_b_scale_factor = 10u64.pow(coin_b_decimals);
        let amount = (conversion_coin.value() * coin_b_scale_factor) / (conversio_rate * coin_a_scale_factor);
        let coin_balance : Balance<T0> = conversion_coin.into_balance();
        assert!(amount <= pool.coin_b.value(), 0);
        balance::join(&mut pool.coin_a, coin_balance);
        let b_coin = coin::take(&mut pool.coin_b, amount, ctx);
        transfer::public_transfer(b_coin, sender);
        event::emit(SwapCreated{
            pool_id: *pool.id.as_inner(),
            conversio_rate,
            input_coin_type: type_name::get<T0>(),
            output_coin_type: type_name::get<T1>(),
            input_coin_amount: conversion_coin.value(),
            output_coin_amount: amount,
        });
    }

    #[allow(lint(self_transfer))]
    public fun convert_b_to_a<T0, T1>(pool: &mut Pool<T0, T1>, conversion_coin: Coin<T1>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
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
            output_coin_type: type_name::get<T0>(),
            input_coin_amount: conversion_coin.value(),
            output_coin_amount: amount,
        });
    }

    fun spilt_rewards_a<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, ctx: &mut TxContext){
        if(pool.coin_a.value() > 1000000){
            let type_name = type_name::get<T0>();
            let mut i = 0;
            let rewards_value = pool.coin_a_rewards.value();
            let payfrica_reward_value = rewards_value / 10;
            let general_reward_value = rewards_value - payfrica_reward_value;
            let payfrica_reward = coin::take(&mut pool.coin_a, payfrica_reward_value, ctx);
            if (payfrica_pool.tokens.contains(&type_name)){
                let payfrica_reward_balance  = payfrica_pool.rewards.borrow_mut<u64, Balance<T0>>(get_token_list_index(payfrica_pool.tokens, type_name));
                coin::put(payfrica_reward_balance, payfrica_reward)
            } else {
                payfrica_pool.tokens.push_back(type_name);
                payfrica_pool.rewards.add(type_name, payfrica_reward.into_balance());
            };
            while (i < pool.coin_a_liquidity_providers_list.length()){
                let provider = pool.coin_a_liquidity_providers_list.borrow(i);
                let provider_details = pool.coin_a_liquidity_providers.borrow_mut(*provider);

                let reward_share = provider_details.amount  * general_reward_value / pool.coin_a.value();
                let reward = coin::take(&mut pool.coin_a, reward_share, ctx);
                coin::put(&mut provider_details.rewards, reward);
                i = i + 1;
            }
        }
    }

    fun spilt_rewards_b<T0, T1>(
        pool: &mut Pool<T0, T1>, 
        payfrica_pool: &mut PayfricaPool, 
        ctx: &mut TxContext
    ){
        if(pool.coin_a.value() > 1000000){
            let type_name = type_name::get<T1>();
            let mut i = 0;
            let rewards_value = pool.coin_a_rewards.value();
            let payfrica_reward_value = rewards_value / 10;
            let general_reward_value = rewards_value - payfrica_reward_value;
            let payfrica_reward = coin::take(
                &mut pool.coin_b, 
                payfrica_reward_value,
                 ctx
            );
            if (payfrica_pool.tokens.contains(&type_name)){
                let payfrica_reward_balance  = payfrica_pool.rewards.borrow_mut<u64, Balance<T1>>(
                    get_token_list_index(
                        payfrica_pool.tokens, 
                        type_name
                    )
                );
                coin::put(payfrica_reward_balance, payfrica_reward)
            } else {
                payfrica_pool.tokens.push_back(type_name);
                payfrica_pool.rewards.add(type_name, payfrica_reward.into_balance());
            };
            while (i < pool.coin_b_liquidity_providers_list.length()){
                let provider = pool.coin_b_liquidity_providers_list.borrow(i);
                let provider_details = pool.coin_b_liquidity_providers.borrow_mut(*provider);

                let reward_share = provider_details.amount  * general_reward_value / pool.coin_b.value();
                let reward = coin::take(&mut pool.coin_b, reward_share, ctx);
                coin::put(&mut provider_details.rewards, reward);
                i = i + 1;
            }
        }
    }


    fun get_token_list_index(list: vector<TypeName>, token: TypeName) : u64{
        let mut i = 0;
        while(i < list.length()){
            if (list.borrow(i) == token){
                return i
            };
            i = i + 1;
        };
        return 0
    }

    public fun claim_rewards_a<T0, T1>(pool: &mut Pool<T0, T1>,ctx: &mut TxContext){
        let reward = pool.coin_a_liquidity_providers.borrow_mut(ctx.sender()).rewards.withdraw_all();
        transfer::public_transfer(reward.into_coin(ctx), ctx.sender());
    }

    public fun claim_rewards_b<T0, T1>(pool: &mut Pool<T0, T1>,ctx: &mut TxContext){
        let reward = pool.coin_b_liquidity_providers.borrow_mut(ctx.sender()).rewards.withdraw_all();
        transfer::public_transfer(reward.into_coin(ctx), ctx.sender());
    }

    public fun get_pool_id<T0, T1>(pool: &Pool<T0, T1>) :ID{
        *pool.id.as_inner()
    }

    fun remove_address_from_list(list: vector<address>, addr: address){
        let mut i = 0;
        while(i < list.length()){
            if (list.borrow(i) == addr){
                list.remove(i);
                break
            }
        }
    }
}

module payfrica::pool_tickets{
    use std::{
        string::{Self, String},
        type_name::TypeName,
    };

    use sui::{
        url::{Self, Url},
        clock::{Clock},
        event,
    };

    public struct PayfricaPoolTicket has key{
        id: UID,
        pool_id: ID,
        coin_type: TypeName,
        amount_added: u64,
        time: u64,
        owner: address,
    }

    
}