module payfrica::pool{
    use sui::{
        balance::{Self, Balance},
        coin::{Self, Coin,},
        table::{Table, new},
        bag::{Self, Bag},
        event,
        package::{Self, Publisher}
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

    const ENotAuthorized : u64 = 0;
    const ESameSwapFee: u64 = 1;
    const EInvalidCoinValue: u64 = 2;
    const ENotALiquidityProvider: u64 = 3;
    const ENotEnoughLiquidity: u64 = 4;
    const ENotEnoughLiquidityOnPool: u64 = 5;
    const EFeeScenerioDoesNotExist: u64 = 6;

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
        swap_fees_a: Table<u64, Fee>,
        swap_fees_b: Table<u64, Fee>,
        defualt_fees_a: Option<u64>, //Percentage 1% --> 100
        defualt_fees_b: Option<u64>, //Percentage 
    }

    public struct Providers<phantom T> has store{
        amount: u64,
        rewards: Balance<T>,
    }

    public struct Fee has store, drop{
        threshold: u64,
        fee: u64,
    }

    public struct PoolCreatedEvent has copy, drop{
        pool_id: ID,
        coin_a_type: TypeName,
        coin_b_type: TypeName,
    }

    public struct SwapCreatedEvent has copy, drop{
        pool_id: ID,
        conversio_rate: u64,
        input_coin_type: TypeName,
        output_coin_type: TypeName,
        input_coin_amount: u64,
        output_coin_amount: u64,
        coin_a_balance: u64,
        coin_b_balance: u64,
    }

    public struct AddedToLiquidityPoolEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        amount: u64,
        coin_a_balance: u64,
        coin_b_balance: u64,
    }

    public struct RemovedFromLiquidityPoolEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        amount: u64,
        coin_a_balance: u64,
        coin_b_balance: u64,
    }

    public struct PoolDefualtFeesUpdatedEvent has copy, drop{
        pool_id: ID,
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        defualt_fees_a: u64,
        defualt_fees_b: u64,
    }

    public struct PoolSwapFeesScenerioAddedEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        threshold: u64,
        fee: u64,
    }

    public struct PoolSwapFeesScenerioRemovedEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        threshold: u64,
    }

    public struct PoolSwapFeesScenerioUpdatedEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        threshold: u64,
        old_fee: u64,
        new_fee: u64,
    }

    public struct PoolRewardClaimEvent has copy, drop{
        pool_id: ID,
        coin_type: TypeName,
        amount: u64,
    }

    fun init(otw: POOL,ctx: &mut TxContext){
        let publisher : Publisher = package::claim(otw, ctx);
        let pool: PayfricaPool = PayfricaPool{
            id: object::new(ctx),
            tokens: vector::empty<TypeName>(),
            rewards: bag::new(ctx),
        };
        transfer::public_transfer(publisher, ctx.sender());
        transfer::share_object(pool);
    }
    
    public fun new_pool<T0, T1>(cap : &Publisher,ctx: &mut TxContext){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let pool = Pool{
            id: object::new(ctx),
            coin_a: balance::zero<T0>(),
            coin_b: balance::zero<T1>(),
            coin_a_rewards: balance::zero<T0>(),
            coin_b_rewards: balance::zero<T1>(),
            coin_a_liquidity_providers: new<address, Providers<T0>>(ctx),
            coin_b_liquidity_providers: new<address, Providers<T1>>(ctx),
            coin_a_liquidity_providers_list: vector::empty<address>(),
            coin_b_liquidity_providers_list: vector::empty<address>(),
            swap_fees_a: new<u64, Fee>(ctx),
            swap_fees_b: new<u64, Fee>(ctx),
            defualt_fees_a: option::none(),
            defualt_fees_b: option::none(),
        };

        let pool_id =  pool.id.as_inner();
        event::emit(PoolCreatedEvent{ 
            pool_id: *pool_id,
            coin_a_type: type_name::get<T0>(),
            coin_b_type: type_name::get<T1>(),
        });
        transfer::public_share_object(pool);
    }

    public fun set_default_fees<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, defualt_fees_a: u64, defualt_fees_b: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        pool.defualt_fees_a = option::some(defualt_fees_a);
        pool.defualt_fees_b = option::some(defualt_fees_b);

        event::emit(
            PoolDefualtFeesUpdatedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type_a: type_name::get<T0>(),
                coin_type_b: type_name::get<T1>(),
                defualt_fees_a,
                defualt_fees_b,
            }
        );
    }

    public fun add_swap_fees_scenario_a<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64, fee: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = pool.swap_fees_a.length();
        pool.swap_fees_a.add(i, Fee{threshold, fee});
        event::emit(
            PoolSwapFeesScenerioAddedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T0>(),
                threshold,
                fee,
            }
        );
    }

    public fun add_swap_fees_scenario_b<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64, fee: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = pool.swap_fees_b.length();
        pool.swap_fees_b.add(i, Fee{threshold, fee});
        event::emit(
            PoolSwapFeesScenerioAddedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T1>(),
                threshold,
                fee,
            }
        );
    }

    public fun remove_swap_fees_scenario_a<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = get_fees_index(&pool.swap_fees_a, threshold);
        pool.swap_fees_a.remove(i);
        event::emit(
            PoolSwapFeesScenerioRemovedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T0>(),
                threshold,
            }
        );
    }

    public fun remove_swap_fees_scenario_b<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = get_fees_index(&pool.swap_fees_a, threshold);
        pool.swap_fees_a.remove(i);
        event::emit(
            PoolSwapFeesScenerioRemovedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T1>(),
                threshold,
            }
        );
    }

    public fun update_swap_fees_scenario_a<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64, fee: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = get_fees_index(&pool.swap_fees_a, threshold);
        assert!(pool.swap_fees_a.borrow(i).fee != fee, ESameSwapFee);
        let old_fee = pool.swap_fees_a.borrow(i).fee;
        pool.swap_fees_a.borrow_mut(i).fee = fee;
        event::emit(
            PoolSwapFeesScenerioUpdatedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T0>(),
                threshold,
                old_fee,
                new_fee: fee,
            }
        );
    }

    public fun update_swap_fees_scenario_b<T0, T1>(pool: &mut Pool<T0, T1>, cap : &Publisher, threshold: u64, fee: u64){
        assert!(cap.from_module<PayfricaPool>(), ENotAuthorized);
        let i = get_fees_index(&pool.swap_fees_b, threshold);
        assert!(pool.swap_fees_b.borrow(i).fee != fee, ESameSwapFee);
        let old_fee = pool.swap_fees_a.borrow(i).fee;
        pool.swap_fees_b.borrow_mut(i).fee = fee;
        event::emit(
            PoolSwapFeesScenerioUpdatedEvent{
                pool_id: *pool.id.as_inner(),
                coin_type: type_name::get<T1>(),
                threshold,
                old_fee,
                new_fee: fee,
            }
        );
    }

    public fun add_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, liquidity_coin: Coin<T0>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(EInvalidCoinValue != 0, 0);
        spilt_rewards_a(pool, payfrica_pool, ctx);
        if (pool.coin_a_liquidity_providers.contains(sender)){
            let provider = pool.coin_a_liquidity_providers.borrow_mut(sender);
            provider.amount = provider.amount + amount;
        } else{
            let providers = Providers<T0>{
                amount,
                rewards: balance::zero<T0>()
            };
            pool.coin_a_liquidity_providers.add(sender, providers);
            pool.coin_a_liquidity_providers_list.push_back(sender);
        };
        let coin_balance : Balance<T0> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_a, coin_balance);
        event::emit(AddedToLiquidityPoolEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    public fun add_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, liquidity_coin: Coin<T1>,ctx: &mut TxContext){
        let sender = ctx.sender();
        let amount = liquidity_coin.value();
        assert!(amount != 0, EInvalidCoinValue);
        spilt_rewards_b(pool, payfrica_pool, ctx);
        if (pool.coin_b_liquidity_providers.contains(sender)){
            let provider = pool.coin_b_liquidity_providers.borrow_mut(sender);
            provider.amount = provider.amount + amount;
        } else{
            let providers = Providers<T1>{
                amount,
                rewards: balance::zero<T1>()
            };
            pool.coin_b_liquidity_providers.add(sender, providers);
            pool.coin_b_liquidity_providers_list.push_back(sender);
        };
        let coin_balance : Balance<T1> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_b, coin_balance);
        event::emit(AddedToLiquidityPoolEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T1>(),
            amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(pool.coin_a_liquidity_providers.contains(sender), ENotALiquidityProvider);
        let liquidity_provider = pool.coin_a_liquidity_providers.borrow_mut(sender);
        let mut liquidity_amount = liquidity_provider.amount;
        assert!(amount <= liquidity_amount, ENotEnoughLiquidity);
        if (amount == liquidity_amount){
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            claim_rewards_a(pool, ctx);
            remove_address_from_list(pool.coin_a_liquidity_providers_list, sender);
            let provider = pool.coin_a_liquidity_providers.remove(sender);
            let Providers{ amount: _, rewards} = provider;
            rewards.destroy_zero();
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_a, amount, ctx);
            liquidity_amount = liquidity_amount - amount;
            liquidity_provider.amount = liquidity_amount;
            claim_rewards_a(pool, ctx);
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(RemovedFromLiquidityPoolEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
        let sender = ctx.sender();
        assert!(pool.coin_b_liquidity_providers.contains(sender), ENotALiquidityProvider);
        let liquidity_provider = pool.coin_b_liquidity_providers.borrow_mut(sender);
        let mut liquidity_amount = liquidity_provider.amount;
        assert!(amount <= liquidity_amount, ENotEnoughLiquidity);
        if (amount == liquidity_amount){
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            claim_rewards_b(pool, ctx);
            remove_address_from_list(pool.coin_b_liquidity_providers_list, sender);
            let provider = pool.coin_b_liquidity_providers.remove(sender);
            let Providers{ amount: _, rewards} = provider;
            rewards.destroy_zero();
            transfer::public_transfer(liquidity_coin, sender);
        } else {
            let liquidity_coin = coin::take(&mut pool.coin_b, amount, ctx);
            liquidity_amount = liquidity_amount - amount;
            liquidity_provider.amount = liquidity_amount;
            claim_rewards_b(pool, ctx);
            transfer::public_transfer(liquidity_coin, sender);
        };
        event::emit(RemovedFromLiquidityPoolEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    #[allow(lint(self_transfer))]
    public fun convert_a_to_b<T0, T1>(pool: &mut Pool<T0, T1>, conversion_coin: Coin<T0>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
        let sender = ctx.sender();
        let coin_value = conversion_coin.value();
        assert!(coin_value > 0, EInvalidCoinValue);
        let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
        let coin_b_scale_factor = 10u64.pow(coin_b_decimals);

        let fee = (coin_value * get_fees_a(pool, coin_value)) / 10_000;
        let net_coin_value = coin_value - fee;

        let amount = (net_coin_value * coin_b_scale_factor) / (conversio_rate * coin_a_scale_factor);
        assert!(amount <= pool.coin_b.value(), ENotEnoughLiquidityOnPool);

        let mut coin_balance  : Balance<T0> = conversion_coin.into_balance();
        let fee_coin = coin::take(&mut coin_balance, fee, ctx);

        balance::join(&mut pool.coin_a_rewards, fee_coin.into_balance());

        balance::join(&mut pool.coin_a, coin_balance);

        let b_coin = coin::take(&mut pool.coin_b, amount, ctx);
        transfer::public_transfer(b_coin, sender);
        event::emit(SwapCreatedEvent{
            pool_id: *pool.id.as_inner(),
            conversio_rate,
            input_coin_type: type_name::get<T0>(),
            output_coin_type: type_name::get<T1>(),
            input_coin_amount: coin_value,
            output_coin_amount: amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    #[allow(lint(self_transfer))]
    public fun convert_b_to_a<T0, T1>(pool: &mut Pool<T0, T1>, conversion_coin: Coin<T1>, conversio_rate : u64, coin_a_decimals: u8, coin_b_decimals: u8, ctx: &mut TxContext){
        let sender = ctx.sender();
        let coin_value = conversion_coin.value();
        assert!(coin_value > 0, EInvalidCoinValue);
        let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
        let coin_b_scale_factor = 10u64.pow(coin_b_decimals);

        let fee = (coin_value * get_fees_b(pool, coin_value)) / 10_000;
        let net_coin_value = coin_value - fee;

        let amount = ((net_coin_value * conversio_rate) / coin_b_scale_factor) * coin_a_scale_factor;
        assert!(amount <= pool.coin_a.value(), ENotEnoughLiquidityOnPool);

        let mut coin_balance : Balance<T1> = conversion_coin.into_balance();
        let fee_coin = coin::take(&mut coin_balance, fee, ctx);

        balance::join(&mut pool.coin_b_rewards, fee_coin.into_balance());
        
        balance::join(&mut pool.coin_b, coin_balance);
        let a_coin = coin::take(&mut pool.coin_a, amount, ctx);
        transfer::public_transfer(a_coin, sender);
        event::emit(SwapCreatedEvent{
            pool_id: *pool.id.as_inner(),
            conversio_rate,
            input_coin_type: type_name::get<T1>(),
            output_coin_type: type_name::get<T0>(),
            input_coin_amount: coin_value,
            output_coin_amount: amount,
            coin_a_balance: pool.coin_a.value(),
            coin_b_balance: pool.coin_b.value(),
        });
    }

    public fun get_fess_convert_a_to_b<T0, T1>(pool: &Pool<T0, T1>, coin_value: u64) : u64{
        let fee = (coin_value * get_fees_a(pool, coin_value)) / 10_000;
        fee
    }

    public fun get_fess_convert_b_to_a<T0, T1>(pool: &Pool<T0, T1>, coin_value: u64) : u64{
        let fee = (coin_value * get_fees_b(pool, coin_value)) / 10_000;
        fee
    }

    fun spilt_rewards_a<T0, T1>(pool: &mut Pool<T0, T1>, payfrica_pool: &mut PayfricaPool, ctx: &mut TxContext){
        if(pool.coin_a_rewards.value() > 1000000){
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
        if(pool.coin_b_rewards.value() > 1000000){
            let type_name = type_name::get<T1>();
            let mut i = 0;
            let rewards_value = pool.coin_b_rewards.value();
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

    fun get_fees_a<T0, T1>(pool: &Pool<T0, T1>, amount: u64) : u64{
        let mut i = 0;
        let mut fees = 0;
        if (pool.defualt_fees_a.is_some()){
            fees = *pool.defualt_fees_a.borrow();
        };
        while(i < pool.swap_fees_a.length()){
            if (amount > pool.swap_fees_a.borrow(i).threshold){
                fees = pool.swap_fees_a.borrow(i).fee;
                break
            };
            i = i + 1;
        };
        fees
    }

    fun get_fees_b<T0, T1>(pool: &Pool<T0, T1>, amount: u64) : u64{
        let mut i = 0;
        let mut fees = 0;
        if (pool.defualt_fees_b.is_some()){
            fees = *pool.defualt_fees_b.borrow();
        };
        while(i < pool.swap_fees_b.length()){
            if (amount > pool.swap_fees_b.borrow(i).threshold){
                fees = pool.swap_fees_b.borrow(i).fee;
                break
            };
            i = i + 1;
        };
        fees
    }

    #[allow(lint(self_transfer))]
    public fun claim_rewards_a<T0, T1>(pool: &mut Pool<T0, T1>,ctx: &mut TxContext){
        let reward = pool.coin_a_liquidity_providers.borrow_mut(ctx.sender()).rewards.withdraw_all();
        let reward_value =  reward.value();
        transfer::public_transfer(reward.into_coin(ctx), ctx.sender());
        event::emit(PoolRewardClaimEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T0>(),
            amount: reward_value,
        });
    }

    #[allow(lint(self_transfer))]
    public fun claim_rewards_b<T0, T1>(pool: &mut Pool<T0, T1>,ctx: &mut TxContext){
        let reward = pool.coin_b_liquidity_providers.borrow_mut(ctx.sender()).rewards.withdraw_all();
        let reward_value =  reward.value();
        transfer::public_transfer(reward.into_coin(ctx), ctx.sender());
        event::emit(PoolRewardClaimEvent{
            pool_id: *pool.id.as_inner(),
            coin_type: type_name::get<T1>(),
            amount: reward_value,
        });
    }

    public fun get_rewards_value_a<T0, T1>(pool: &Pool<T0, T1>, addr: address) : u64{
        pool.coin_a_liquidity_providers.borrow(addr).rewards.value()
    }

    public fun get_rewards_value_b<T0, T1>(pool: &Pool<T0, T1>, addr: address) : u64{
        pool.coin_b_liquidity_providers.borrow(addr).rewards.value()
    }

    public fun get_pool_id<T0, T1>(pool: &Pool<T0, T1>) :ID{
        *pool.id.as_inner()
    }

    fun remove_address_from_list(mut list: vector<address>, addr: address){
        let mut i = 0;
        while(i < list.length()){
            if (list.borrow(i) == addr){
                list.remove(i);
                break
            };
            i = i + 1;
        }
    }

    fun get_fees_index(fees: &Table<u64, Fee>, threshold: u64) : u64{
        let mut i = 0;
        let mut index = 0;
        while(i < fees.length()){
            if (threshold == fees.borrow(i).threshold){
                index = i;
            };
            i = i + 1;
        };
        assert!(index != 0, EFeeScenerioDoesNotExist);
        index
    }

    #[test_only]
    public fun call_init(ctx: &mut TxContext){
        let otw = POOL{};
        init(otw, ctx);
    }
}

// module payfrica::pool_tickets{
//     use std::{
//         string::{Self, String},
//         type_name::TypeName,
//     };

//     use sui::{
//         url::{Self, Url},
//         clock::{Clock},
//         event,
//     };

//     public struct PayfricaPoolTicket has key{
//         id: UID,
//         pool_id: ID,
//         coin_type: TypeName,
//         amount_added: u64,
//         time: u64,
//         owner: address,
//     }
// }