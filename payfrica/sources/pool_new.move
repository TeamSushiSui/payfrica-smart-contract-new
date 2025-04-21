module payfrica::pool_new;
use sui::{
    balance::{Self, Balance},
    coin::{Self, Coin,},
    table::{Table, new},
    bag::{Self, Bag},
    event,
    package::{Self, Publisher}
};
use std::{
    type_name::{Self, TypeName},
};

const ENotAuthorized : u64 = 0;
const ESameSwapFee: u64 = 1;
const EInvalidCoinValue: u64 = 2;
const ENotALiquidityProvider: u64 = 3;
const ENotEnoughLiquidity: u64 = 4;
const ENotEnoughLiquidityOnPool: u64 = 5;
const EFeeScenerioDoesNotExist: u64 = 6;


public struct Payfrica has key{
    id: UID,
    tokens: vector<TypeName>,
    rewards: Bag,
}

public struct POOL_NEW has drop {}

public struct Pool<phantom T> has store, key{
    id: UID,
    coin: Balance<T>,
    rewards: Balance<T>,
    liquidity_providers: Table<address, Providers<T>>,
    liquidity_providers_list: vector<address>,
    swap_fees: Table<u64, Fee>,
    defualt_fees: Option<u64>, //Percentage 1% --> 100
    fee_decimal: u8,
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
    pool_id: address,
    coin_type: TypeName,
}

public struct PoolDefualtFeesUpdatedEvent has copy, drop{
    pool_id: address,
    coin_type_a: TypeName,
    defualt_fees: u64,
}

public struct PoolSwapFeesScenerioAddedEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    threshold: u64,
    fee: u64,
}

public struct PoolSwapFeesScenerioRemovedEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    threshold: u64,
}

public struct PoolSwapFeesScenerioUpdatedEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    threshold: u64,
    old_fee: u64,
    new_fee: u64,
}

public struct PoolRewardClaimEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    amount: u64,
}

public struct AddedToLiquidityPoolEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    amount: u64,
    coin_balance: u64,
}

public struct RemovedFromLiquidityPoolEvent has copy, drop{
    pool_id: address,
    coin_type: TypeName,
    amount: u64,
    coin_balance: u64,
}

public struct SwapCreatedEvent has copy, drop{
    pool_a_id: address,
    pool_b_id: address,
    conversion_rate: u64,
    conversion_r_scale_decimal: u8,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    input_coin_amount: u64,
    output_coin_amount: u64,
    coin_a_balance: u64,
    coin_b_balance: u64,
}

fun init(otw: POOL_NEW,ctx: &mut TxContext){
    let publisher : Publisher = package::claim(otw, ctx);
    let pool = Payfrica{
        id: object::new(ctx),
        tokens: vector::empty<TypeName>(),
        rewards: bag::new(ctx),
    };
    transfer::public_transfer(publisher, ctx.sender());
    transfer::share_object(pool);
}

public fun create_new_pool<T>(cap : &Publisher, ctx: &mut TxContext) {
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    let pool = Pool {
        id: object::new(ctx),
        coin: balance::zero<T>(),
        rewards: balance::zero<T>(),
        liquidity_providers:  new<address, Providers<T>>(ctx),
        liquidity_providers_list: vector::empty<address>(),
        swap_fees: new<u64, Fee>(ctx),
        defualt_fees: option::none<u64>(),
        fee_decimal: 2,
    };
    let pool_id = object::id_address(&pool);
    event::emit(PoolCreatedEvent{ 
        pool_id,
        coin_type: type_name::get<T>(),
    });
    transfer::public_share_object(pool);
}

public fun add_mint<T>(pool: &mut Pool<T>, coin: Coin<T>, ctx: &mut TxContext) {
    let coin_value = coin.value();
    assert!(coin_value > 0, EInvalidCoinValue);
    pool.coin.join(coin.into_balance());
}

public fun set_default_fees<T>(pool: &mut Pool<T>, cap : &Publisher, defualt_fees: u64){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    pool.defualt_fees = option::some(defualt_fees);

    event::emit(
        PoolDefualtFeesUpdatedEvent{
            pool_id: object::id_address(pool),
            coin_type_a: type_name::get<T>(),
            defualt_fees,
        }
    );
}

public fun add_swap_fees_scenario<T>(pool: &mut Pool<T>, cap : &Publisher, threshold: u64, fee: u64){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    let i = pool.swap_fees.length();
    pool.swap_fees.add(i, Fee{threshold, fee});
    event::emit(
        PoolSwapFeesScenerioAddedEvent{
            pool_id: object::id_address(pool),
            coin_type: type_name::get<T>(),
            threshold,
            fee,
        }
    );
}

public fun remove_swap_fees_scenario<T>(pool: &mut Pool<T>, cap : &Publisher, threshold: u64){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    let i = get_fees_index(&pool.swap_fees, threshold);
    pool.swap_fees.remove(i);
    event::emit(
        PoolSwapFeesScenerioRemovedEvent{
            pool_id: object::id_address(pool),
            coin_type: type_name::get<T>(),
            threshold,
        }
    );
}

public fun update_swap_fees_scenario<T>(pool: &mut Pool<T>, cap : &Publisher, threshold: u64, fee: u64){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    let i = get_fees_index(&pool.swap_fees, threshold);
    assert!(pool.swap_fees.borrow(i).fee != fee, ESameSwapFee);
    let old_fee = pool.swap_fees.borrow(i).fee;
    pool.swap_fees.borrow_mut(i).fee = fee;
    event::emit(
        PoolSwapFeesScenerioUpdatedEvent{
            pool_id: object::id_address(pool),
            coin_type: type_name::get<T>(),
            threshold,
            old_fee,
            new_fee: fee,
        }
    );
}

public fun add_liquidity<T>(pool: &mut Pool<T>, payfrica: &mut Payfrica, liquidity_coin: Coin<T>,ctx: &mut TxContext){
    let sender = ctx.sender();
    let amount = liquidity_coin.value();
    assert!(EInvalidCoinValue != 0, 0);
    spilt_rewards(pool, payfrica, ctx);
    if (pool.liquidity_providers.contains(sender)){
        let provider = pool.liquidity_providers.borrow_mut(sender);
        provider.amount = provider.amount + amount;
    } else{
        let providers = Providers<T>{
            amount,
            rewards: balance::zero<T>()
        };
        pool.liquidity_providers.add(sender, providers);
        pool.liquidity_providers_list.push_back(sender);
    };
    let coin_balance : Balance<T> = liquidity_coin.into_balance();
    balance::join(&mut pool.coin, coin_balance);
    event::emit(AddedToLiquidityPoolEvent{
        pool_id: object::id_address(pool),
        coin_type: type_name::get<T>(),
        amount,
        coin_balance: pool.coin.value(),
    });
}

#[allow(lint(self_transfer))]
public fun remove_liquidity<T>(pool: &mut Pool<T>, amount: u64,ctx: &mut TxContext){
    let sender = ctx.sender();
    assert!(pool.liquidity_providers.contains(sender), ENotALiquidityProvider);
    let liquidity_provider = pool.liquidity_providers.borrow_mut(sender);
    let mut liquidity_amount = liquidity_provider.amount;
    assert!(amount <= liquidity_amount, ENotEnoughLiquidity);
    if (amount == liquidity_amount){
        let liquidity_coin = coin::take(&mut pool.coin, amount, ctx);
        claim_rewards(pool, ctx);
        remove_address_from_list(pool.liquidity_providers_list, sender);
        let provider = pool.liquidity_providers.remove(sender);
        let Providers{ amount: _, rewards} = provider;
        rewards.destroy_zero();
        transfer::public_transfer(liquidity_coin, sender);
    } else {
        let liquidity_coin = coin::take(&mut pool.coin, amount, ctx);
        liquidity_amount = liquidity_amount - amount;
        liquidity_provider.amount = liquidity_amount;
        claim_rewards(pool, ctx);
        transfer::public_transfer(liquidity_coin, sender);
    };
    event::emit(RemovedFromLiquidityPoolEvent{
        pool_id: object::id_address(pool),
        coin_type: type_name::get<T>(),
        amount,
        coin_balance: pool.coin.value(),
    });
}

fun spilt_rewards<T>(pool: &mut Pool<T>, payfrica: &mut Payfrica, ctx: &mut TxContext){
    if(pool.rewards.value() > 1000000){
        let type_name = type_name::get<T>();
        let mut i = 0;
        let rewards_value = pool.rewards.value();
        let payfrica_reward_value = rewards_value / 10;
        let general_reward_value = rewards_value - payfrica_reward_value;
        let payfrica_reward = coin::take(&mut pool.coin, payfrica_reward_value, ctx);
        if (payfrica.tokens.contains(&type_name)){
            let payfrica_reward_balance  = payfrica.rewards.borrow_mut<u64, Balance<T>>(get_token_list_index(payfrica.tokens, type_name));
            coin::put(payfrica_reward_balance, payfrica_reward)
        } else {
            payfrica.tokens.push_back(type_name);
            payfrica.rewards.add(type_name, payfrica_reward.into_balance());
        };
        while (i < pool.liquidity_providers_list.length()){
            let provider = pool.liquidity_providers_list.borrow(i);
            let provider_details = pool.liquidity_providers.borrow_mut(*provider);

            let reward_share = provider_details.amount  * general_reward_value / pool.coin.value();
            let reward = coin::take(&mut pool.coin, reward_share, ctx);
            coin::put(&mut provider_details.rewards, reward);
            i = i + 1;
        }
    }
}

#[allow(lint(self_transfer))]
public fun claim_rewards<T>(pool: &mut Pool<T>,ctx: &mut TxContext){
    let reward = pool.liquidity_providers.borrow_mut(ctx.sender()).rewards.withdraw_all();
    let reward_value =  reward.value();
    transfer::public_transfer(reward.into_coin(ctx), ctx.sender());
    event::emit(PoolRewardClaimEvent{
        pool_id: object::id_address(pool),
        coin_type: type_name::get<T>(),
        amount: reward_value,
    });
}

#[allow(lint(self_transfer))]
public fun convert_a_to_b<T0, T1>(pool_a: &mut Pool<T0>, pool_b: &mut Pool<T1>, conversion_coin: Coin<T0>, conversion_rate : u64, conversion_r_scale_decimal: u8, ctx: &mut TxContext){
    let sender = ctx.sender();
    let coin_value = conversion_coin.value();
    assert!(coin_value > 0, EInvalidCoinValue);
    // let coin_a_scale_factor = 10u64.pow(coin_a_decimals);
    let conversion_r_scale_factor = 10u64.pow(conversion_r_scale_decimal);

    let fee = (coin_value * get_fees(pool_a, coin_value)) / 10_000;
    let net_coin_value = coin_value - fee;

    let amount = (net_coin_value * conversion_rate) / (conversion_r_scale_factor);
    assert!(amount <= pool_b.coin.value(), ENotEnoughLiquidityOnPool);

    let mut coin_balance  : Balance<T0> = conversion_coin.into_balance();
    let fee_coin = coin::take(&mut coin_balance, fee, ctx);

    balance::join(&mut pool_a.rewards, fee_coin.into_balance());

    balance::join(&mut pool_a.coin, coin_balance);

    let b_coin = coin::take(&mut pool_b.coin, amount, ctx);
    transfer::public_transfer(b_coin, sender);
    event::emit(SwapCreatedEvent{
        pool_a_id: object::id_address(pool_a),
        pool_b_id: object::id_address(pool_b),
        conversion_rate,
        conversion_r_scale_decimal,
        input_coin_type: type_name::get<T0>(),
        output_coin_type: type_name::get<T1>(),
        input_coin_amount: coin_value,
        output_coin_amount: amount,
        coin_a_balance: pool_a.coin.value(),
        coin_b_balance: pool_a.coin.value(),
    });
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

fun get_fees<T>(pool: &Pool<T>, amount: u64) : u64{
    let mut i = 0;
    let mut fees = 0;
    if (pool.defualt_fees.is_some()){
        fees = *pool.defualt_fees.borrow();
    };
    while(i < pool.swap_fees.length()){
        if (amount > pool.swap_fees.borrow(i).threshold){
            fees = pool.swap_fees.borrow(i).fee;
            break
        };
        i = i + 1;
    };
    fees
}

#[test_only]
public fun call_init(ctx: &mut TxContext){
    let otw = POOL_NEW{};
    init(otw, ctx);
}

