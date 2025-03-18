module payfrica::vault{
    use sui::{
        coin::Coin,
        balance::{Self, Balance},
        clock::{Self, Clock}
    };

    use std::type_name;

    use payfrica::{
        pool::{Self, Pool},
        vault_ticket::{Self, ValutTicket},
        ngnc::NGNC,
    };

    const EInvalidUnlockTime: u64 = 0;
    const EUnlockTimeNotReached: u64 = 1;
    const EInvalidUnlockCoinType: u64 = 2;
    const ENotTicketOwner: u64 = 3;
    const EInvalidCoinValue: u64 = 4;

    public entry fun create_vault_a<NGNC, T1>(
        pool: &mut Pool<NGNC,T1>, 
        lockup_coin: Coin<NGNC>, 
        unlock_time: u64, 
        clock: &Clock, 
        ctx: &mut TxContext
    ){  
        assert!(lockup_coin.value() > 0, EInvalidCoinValue);
        assert!(unlock_time > clock.timestamp_ms(), EInvalidUnlockTime);
        pool::add_liquidity_a(pool, lockup_coin, ctx);
        vault_ticket::get_ticket(pool.get_pool_id(), lockup_coin.value(), clock.timestamp_ms(), unlock_time, type_name::get<NGNC>(), ctx);

    }

    public entry fun create_vault_b<NGNC, T1>(
        pool: &mut Pool<NGNC,T1>, 
        lockup_coin: Coin<T1>, 
        unlock_time: u64, 
        clock: &Clock, 
        ctx: &mut TxContext
    ){  
        assert!(lockup_coin.value() > 0, EInvalidCoinValue);
        assert!(unlock_time > clock.timestamp_ms(), EInvalidUnlockTime);
        pool::add_liquidity_b(pool, lockup_coin, ctx);
        vault_ticket::get_ticket(pool.get_pool_id(), lockup_coin.value(), clock.timestamp_ms(), unlock_time, type_name::get<T1>(), ctx);
    }

    public entry fun unlock_vault_a<NGNC, T1>(
        pool: &mut Pool<NGNC,T1>, 
        ticket: &ValutTicket,
        clock: &Clock, 
        ctx: &mut TxContext
    ){  
        assert!(vault_ticket::get_ticket_unlock_end_time(ticket) < clock.timestamp_ms(), EUnlockTimeNotReached);
        assert!(ticket.get_ticket_owner() == ctx.sender(), ENotTicketOwner);
        assert!(ticket.get_ticket_coin_type() == type_name::get<NGNC>(), EInvalidUnlockCoinType);
        pool.remove_liquidity_a(vault_ticket::get_ticket_amount_locked(ticket), ctx);
    }

    public entry fun unlock_vault_b<NGNC, T1>(
        pool: &mut Pool<NGNC,T1>, 
        ticket: &ValutTicket,
        clock: &Clock, 
        ctx: &mut TxContext
    ){  
        assert!(vault_ticket::get_ticket_unlock_end_time(ticket) < clock.timestamp_ms(), EUnlockTimeNotReached);
        assert!(ticket.get_ticket_owner() == ctx.sender(), ENotTicketOwner);
        assert!(ticket.get_ticket_coin_type() == type_name::get<NGNC>(), EInvalidUnlockCoinType);
        pool.remove_liquidity_a(vault_ticket::get_ticket_amount_locked(ticket), ctx);
    }
}

module payfrica::vault_ticket{
    use std::{
        string::{Self, String},
        type_name::TypeName,
    };

    use sui::{
        url::{Self, Url},
        clock::{Clock},
        event,
    };


    public struct ValutTicket has key, store {
        id: UID,            
        amount_locked: u64,
        pool_id: ID,
        price: u64,       
        url: Url,
        lock_time: u64,
        unlock_time: u64,
        valut_owner : address,
        coin_type: TypeName
    }

    public struct TokenLocked has copy, drop {
        pool_id: ID,         
        owner: address,   
        amount_locked: u64,
        lock_time: u64,
        unlock_time: u64,     
    }

    #[allow(lint(self_transfer))]
    public fun get_ticket(pool_id: ID, amount_locked: u64, lock_time: u64, unlock_time: u64, coin_type: TypeName, ctx: &mut TxContext){
        let sender = ctx.sender();
        let valut_ticket = ValutTicket{
            id: object::new(ctx),
            amount_locked: amount_locked,
            pool_id: pool_id,
            price: 0,
            url: url::new_unsafe_from_bytes(b"url"),
            lock_time,
            unlock_time,
            valut_owner: sender,
            coin_type,
        };

        event::emit(TokenLocked{
            pool_id,
            owner: sender,
            amount_locked,
            lock_time,
            unlock_time,
        });
        transfer::transfer(valut_ticket, sender);
    }

    public fun get_ticket_unlock_end_time(ticket: &ValutTicket) : u64{
        ticket.unlock_time
    }

    public fun get_ticket_owner(ticket: &ValutTicket) : address{
        ticket.valut_owner
    }

    public fun get_ticket_amount_locked(ticket: &ValutTicket) : u64{
        ticket.amount_locked
    }

    public fun get_ticket_coin_type(ticket: &ValutTicket) : TypeName{
        ticket.coin_type
    }
}
