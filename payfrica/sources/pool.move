module payfrica::pool{
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin,};
    use sui::table::{Table, new};
    use sui::dynamic_field as df;

    public struct Pool<phantom T0, phantom T1> has store, key{
        id: UID,
        coin_a: Balance<T0>,
        coin_b: Balance<T1>,
    }

    public struct Providers has store{
        coin_a_liquidity_providers: Table<address, u64>,
        coin_b_liquidity_providers: Table<address, u64>,
    }

    public struct SinglePool<phantom T> has store, key{
        id: UID,
        coin_a: Balance<T>,
    }

    public struct SingleProviders has store{
        liquidity_providers: Table<address, u64>,
    }

    public fun new_pool<T0, T1>(ctx: &mut TxContext){
        let mut pool = Pool{
            id: object::new(ctx),
            coin_a: balance::zero<T0>(),
            coin_b: balance::zero<T1>(),
        };

        let providers = Providers{
            coin_a_liquidity_providers: new<address, u64>(ctx),
            coin_b_liquidity_providers: new<address, u64>(ctx),
        };

        df::add(&mut pool.id, b"providers", providers);

        transfer::public_share_object(pool);
    }

    public fun add_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, liquidity_coin: Coin<T0>,ctx: &mut TxContext){
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
        let coin_balance : Balance<T0> = liquidity_coin.into_balance();
        balance::join(&mut pool.coin_a, coin_balance);
    }

    public fun add_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, liquidity_coin: Coin<T1>,ctx: &mut TxContext){
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
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_a<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
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
    }

    #[allow(lint(self_transfer))]
    public fun remove_liquidity_b<T0, T1>(pool: &mut Pool<T0, T1>, amount: u64,ctx: &mut TxContext){
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
    }
}
