module payfrica::temporary_card;
use payfrica::payfrica::PayfricaUser;
use sui::table::{Self, Table};
use std::ascii::String;
use sui::event;
use sui::clock::Clock;
use sui::coin::Coin;

const ECardBlocked: u64 = 1; 
const ENotAuthorized: u64 = 2;  

public struct PayficaTemporaryCards has key, store{
    id: UID,
    cards: Table<address, TemporaryCard>
}

public struct Transaction has copy, drop, store{
    from: address,
    amount: u64,
    time: u64,
    description: String
}

public struct CardCreatedEvent has copy, drop{
    card_id: ID,
    name: String,
    card_address: address,
    owner: address,
    expiration_date: u64,
    hp: vector<u8>,
    s: String,
    blobId: String,
    blobObjectId: address,
    blobUrl: String,
    creation_time: u64
}

public struct CardUnlockedEvent has copy, drop{
    card_id: ID,
    card_address: address,
    owner: address,
    unlocked_by: address,
    num_unlocks: u8,
    false_attemps: u8,
    blocked: bool,
    time: u64
}

public struct CardBlockedEvent has copy, drop{
    card_id: ID,
    card_address: address,
    owner: address,
    time: u64
}

public struct CardUsedEvent has copy, drop{
    card_id: ID,
    card_address: address,
    receiver: address,
    amount: u64,
    owner: address,
    time: u64
}

public struct CardAddBalanceEvent has copy, drop{
    card_id: ID,
    card_address: address,
    owner: address,
    amount: u64,
    time: u64
}

public struct CardRemoveBalanceEvent has copy, drop{
    card_id: ID,
    card_address: address,
    owner: address,
    amount: u64,
    time: u64
}

public struct TemporaryCard has key, store{
    id: UID,
    name: String,
    owner: address,
    blobId: String,
    blobObjectId: address,
    blobUrl: String,
    s: String,
    card_address: address,
    expiration_date: u64,
    hp: vector<u8>,
    blocked: bool,
    false_attemps: u8,
    num_unlocks: u8,
    Transactions: vector<Transaction>,
    creation_time: u64
}

fun init(ctx: &mut TxContext) {
    let cards = PayficaTemporaryCards{
        id: object::new(ctx),
        cards: table::new<address, TemporaryCard>(ctx),
    };
    transfer::share_object(cards);
}

#[allow(unused_variable)]
public fun create_card(temporary_card: &mut PayficaTemporaryCards, payfrica_user: &mut PayfricaUser, card_address: address, name: String, expiration_date: u64, hp: vector<u8>, s: String, blobId: String, blobObjectId: address, blobUrl: String, clock: &Clock, ctx: &mut TxContext){
    let card = TemporaryCard{
        id: object::new(ctx),
        name,
        owner: ctx.sender(),
        blobId,
        blobObjectId,
        blobUrl,
        s: s,
        card_address,
        expiration_date,
        hp,
        blocked: false,
        false_attemps: 0,
        num_unlocks: 0,
        Transactions: vector::empty<Transaction>(),
        creation_time: clock.timestamp_ms(),
    };
    event::emit({
        CardCreatedEvent{
            card_id: *card.id.as_inner(),
            name,
            card_address,
            owner: ctx.sender(),
            expiration_date,
            hp,
            s,
            blobId,
            blobObjectId,
            blobUrl,
            creation_time: clock.timestamp_ms()
        }
    });
    temporary_card.cards.add(ctx.sender(), card);
    
}

#[allow(unused_variable)]
public fun try_unlock(payfrica_cards: &mut PayficaTemporaryCards, payfrica_user: &mut PayfricaUser, owner: address, card_address: address, hp: vector<u8>, clock: &Clock, ctx: &mut TxContext) : bool{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    if(hp == card.hp){
        card.num_unlocks = card.num_unlocks + 1;
        event::emit({
        CardUnlockedEvent{
            card_id: *card.id.as_inner(),
            card_address,
            owner,
            unlocked_by: ctx.sender(),
            num_unlocks: card.num_unlocks,
            false_attemps: card.false_attemps,
            blocked: card.blocked,
            time: clock.timestamp_ms()
        }
        });
        true
    } else {
        card.false_attemps = card.false_attemps + 1;
        if (card.false_attemps == 3){
            card.blocked = true;
        };
        event::emit(
        CardUnlockedEvent{
            card_id: *card.id.as_inner(),
            card_address,
            owner: ctx.sender(),
            unlocked_by: ctx.sender(),
            num_unlocks: card.num_unlocks,
            false_attemps: card.false_attemps,
            blocked: card.blocked,
            time: clock.timestamp_ms()
        }
        );
        false
    }
}

public fun use_card<T>(payfrica_cards: &mut PayficaTemporaryCards, use_coin: Coin<T>, owner: address, receiver: address, clock: &Clock, ctx: &mut TxContext){
    let card = payfrica_cards.cards.borrow(ctx.sender());
    assert!(!card.blocked, ECardBlocked);
    event::emit(
        CardUsedEvent{
            card_id: *card.id.as_inner(),
            card_address: ctx.sender(),
            receiver,
            amount: use_coin.value(),
            owner,
            time: clock.timestamp_ms()
        }
    );
    transfer::public_transfer(use_coin, receiver);
}

public fun get_card_s(payfrica_cards: &mut PayficaTemporaryCards, card_address: address) : String{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    card.s
}

public fun block_card(payfrica_cards: &mut PayficaTemporaryCards, card_address: address, clock: &Clock, ctx: &mut TxContext){
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(card.owner == ctx.sender(), ENotAuthorized);
    card.blocked = true;

    event::emit(
        CardBlockedEvent{
            card_id: *card.id.as_inner(),
            card_address,
            owner: ctx.sender(),
            time: clock.timestamp_ms()
        }
    );
}

public fun get_num_unlocks(payfrica_cards: &mut PayficaTemporaryCards, card_address: address) : u8{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    card.num_unlocks
}

#[allow(unused_variable)]
public fun seal_approve(payfrica_user: &mut PayfricaUser) {
    
}

#[allow(unused_variable)]
public fun add_balance<T>(payfrica_cards: &PayficaTemporaryCards, payfrica_user: &mut PayfricaUser, add_coin: Coin<T>, card_address: address, clock: &Clock, ctx: &mut TxContext){
    let card = payfrica_cards.cards.borrow(ctx.sender());
    assert!(!card.blocked, ECardBlocked);
    event::emit(
        CardAddBalanceEvent{
            card_id: *card.id.as_inner(),
            card_address,
            owner: ctx.sender(),
            amount: add_coin.value(),
            time: clock.timestamp_ms()
        }
    );
    transfer::public_transfer(add_coin, card_address);
}

public fun remove_balance<T>(payfrica_cards: &PayficaTemporaryCards, remove_coin: Coin<T>, owner: address, clock: &Clock, ctx: &mut TxContext){
    let card = payfrica_cards.cards.borrow(ctx.sender());
    event::emit(
        CardRemoveBalanceEvent{
            card_id: *card.id.as_inner(),
            card_address: ctx.sender(),
            owner,
            amount: remove_coin.value(),
            time: clock.timestamp_ms()
        }
    );
    transfer::public_transfer(remove_coin, owner);
    
}