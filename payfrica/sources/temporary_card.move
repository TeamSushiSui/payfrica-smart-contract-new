module payfrica::temporary_card;
use payfrica::payfrica::PayfricaUser;
use sui::table::{Self, Table};
use std::ascii::String;
use sui::event;
use sui::clock::Clock;

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

public struct TemporaryCard has key, store{
    id: UID,
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


public fun create_card(temporary_card: &mut PayficaTemporaryCards, card_address: address, expiration_date: u64, hp: vector<u8>, s: String, blobId: String, blobObjectId: address, blobUrl: String, clock: &Clock, ctx: &mut TxContext){
    let card = TemporaryCard{
        id: object::new(ctx),
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
    temporary_card.cards.add(ctx.sender(), card);

    event::emit({
        CardCreatedEvent{
            card_id: *card.id.as_inner(),
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
    })
}

#[allow(unused_variable)]
entry fun try_unlock(payfrica_cards: &mut PayficaTemporaryCards, payfrica_user: &mut PayfricaUser, card_address: address, hp: vector<u8>, ctx: &mut TxContext) : bool{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    if(hp == card.hp){
        card.num_unlocks = card.num_unlocks + 1;
        true
    } else {
        card.false_attemps = card.false_attemps + 1;
        if (card.false_attemps == 3){
            card.blocked = true;
        };
        false
    }
}

public fun get_card_s(payfrica_cards: &mut PayficaTemporaryCards, card_address: address) : String{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    card.s
}

entry fun block_card(payfrica_cards: &mut PayficaTemporaryCards, card_address: address, ctx: &mut TxContext){
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(card.owner == ctx.sender(), ENotAuthorized);
    card.blocked = true;
}

public fun get_num_unlocks(payfrica_cards: &mut PayficaTemporaryCards, card_address: address) : u8{
    let card = payfrica_cards.cards.borrow_mut(card_address);
    assert!(!card.blocked, ECardBlocked);
    card.num_unlocks
}

entry fun seal_approve(payfrica_user: &mut PayfricaUser) {
    
}

public fun add_balance<T>(payfrica_user: &mut PayfricaUser, card_address: address, ctx: &mut TxContext){
    
}