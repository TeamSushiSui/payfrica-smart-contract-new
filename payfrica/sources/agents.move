module payfrica::agents;
use sui::{
    coin::{Self,Coin},
    balance::{Self, Balance},
    table::{Self, Table},
    package::{Self, Publisher},
    event,
    clock::{Clock},
    
};

use std::{
    type_name::{Self, TypeName},
    string::String
};

const EInvalidAgentType: u64 = 1;
const ENotAuthorized : u64 = 0;
const EInvalidCoin: u64 = 2;
const EInvalidAgent: u64 = 3;
const EInvalidBalance: u64 = 4;
const ENotInvalidRequest: u64 = 5;
const ENotEnoughAgentBalance: u64 = 6;
const ENotInAgentWithdrawalRange: u64 = 7;
const ENotInAgentDepositRange: u64 = 8;

public enum WithdrawStatus has copy, drop, store{
    Pending,
    Completed,
}

public enum DepositStatus has copy, drop, store{
    Pending,
    Completed,
    Cancelled,
}

public struct AGENTS has drop{}

public struct PayfricaAgents has key{
    id: UID,
    agents: Table<TypeName, vector<address>>, 
    valid_types: vector<TypeName>,
}

public struct WithdrawRequest<phantom T> has key, store{
    id: UID,
    amount: u64,
    user: address,
    agent_id: address,
    coin_type: TypeName,
    status: WithdrawStatus,
    request_time: u64,
    status_time: Option<u64>
}
public struct DepositRequest<phantom T> has key, store{
    id: UID,
    amount: u64,
    agent_id: address,
    user: address,
    coin_type: TypeName,
    comment: String,
    status: DepositStatus,
    request_time: u64,
    status_time: Option<u64>,
}

public struct Agent<phantom T> has key, store{
    id: UID,
    addr: address,
    balance: Balance<T>,
    coin_type: TypeName,
    pending_withdrawals: vector<ID>,
    successful_withdrawals: vector<ID>,
    total_successful_withdrawals: u64,
    total_pending_withdrawals: u64,
    total_successful_withdrawals_amount: u64,
    total_pending_withdrawals_amount: u64,
    pending_deposits: vector<ID>,
    successful_deposits: vector<ID>,
    total_successful_deposits: u64,
    total_pending_deposits: u64,
    total_successful_deposits_amount: u64,
    total_pending_deposits_amount: u64,
    unsuccessful_deposits: vector<ID>,
    total_unsuccessful_deposits: u64,
    max_withdraw_limit: u64,
    max_deposit_limit: u64,
    min_withdraw_limit: u64,
    min_deposit_limit: u64,
}

public struct AgentAddedEvent has copy, drop{
    agent_id: address,
    agent: address,
    agent_type: TypeName,
}

public struct ValidAgentTypeAddedEvent has copy, drop{
    agent_type: TypeName,
}

public struct WithdrawalRequestEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: WithdrawStatus,
    time: u64
}
public struct DepositRequestEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    comment: String,
    status: DepositStatus,
    time: u64
}

public struct WithdrawalApprovedEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: WithdrawStatus,
    time: u64
}

public struct DepositApprovedEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: DepositStatus,
    time: u64
}

public struct DepositCancelledEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: DepositStatus,
    time: u64
}

public struct SetAgentWithdrawalLimitEvent has copy, drop{
    agent_id: address,
    agent_type: TypeName,
    min_withdraw_limit: u64,
    max_withdraw_limit: u64
}
public struct SetAgentDepositLimitEvent has copy, drop{
    agent_id: address,
    agent_type: TypeName,
    min_deposit_limit: u64,
    max_deposit_limit: u64
}

public struct AddAgentBalanceEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    coin_type: TypeName,
    time: u64
}

public struct AgentBalanceWithdrawEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    coin_type: TypeName,
    time: u64
}

fun init(otw: AGENTS, ctx: &mut TxContext) {
    let publisher : Publisher = package::claim(otw, ctx);
    let payfrica_agents = PayfricaAgents {
        id: object::new(ctx),
        agents: table::new<TypeName, vector<address>>(ctx),
        valid_types: vector::empty<TypeName>(),
    };
    transfer::share_object(payfrica_agents);
    transfer::public_transfer(publisher, ctx.sender());
}

public fun create_agent<T>(cap : &Publisher,payfrica_agents: &mut PayfricaAgents, agent_addr: address, ctx: &mut TxContext) {
    let type_name = type_name::get<T>();
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    assert!(payfrica_agents.valid_types.contains(&type_name), EInvalidAgentType);
    let agent = Agent {
        id: object::new(ctx),
        addr: agent_addr,
        balance: balance::zero<T>(),
        coin_type: type_name::get<T>(),
        pending_withdrawals: vector::empty<ID>(),
        successful_withdrawals: vector::empty<ID>(),
        total_successful_withdrawals: 0,
        total_pending_withdrawals: 0,
        total_successful_withdrawals_amount: 0,
        total_pending_withdrawals_amount: 0,
        pending_deposits: vector::empty<ID>(),
        successful_deposits: vector::empty<ID>(),
        total_successful_deposits: 0,
        total_pending_deposits: 0,
        total_successful_deposits_amount: 0,
        total_pending_deposits_amount: 0,
        unsuccessful_deposits: vector::empty<ID>(),
        total_unsuccessful_deposits: 0,
        max_withdraw_limit: 0,
        max_deposit_limit: 0,
        min_withdraw_limit: 0,
        min_deposit_limit: 0,
    };
    let agents = payfrica_agents.agents.borrow_mut(type_name);
    agents.push_back(object::id_address(&agent));
    event::emit(AgentAddedEvent{
        agent_id: object::id_address(&agent),
        agent: agent_addr,
        agent_type: type_name,
    });
    transfer::share_object(agent);
}

// fun get_agent(agents: &vector<address>, agent: address): Age {
//     let mut i = 0;
//     while(i < valid_types.length()){
//         if (valid_types.borrow(i) == type_name) {
//             return true
//         };
//         i = i + 1;
//     };
//     false
// }

public fun add_valid_agent_type<T>(cap : &Publisher,payfrica_agents: &mut PayfricaAgents) {
    let type_name = type_name::get<T>();
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    assert!(!payfrica_agents.valid_types.contains(&type_name), EInvalidAgentType);
    payfrica_agents.valid_types.push_back(type_name);
    payfrica_agents.agents.add(type_name, vector::empty<address>());
    event::emit(ValidAgentTypeAddedEvent{
        agent_type: type_name,
    });
}

public fun withdrawal_request<T>(payfrica_agents: &mut PayfricaAgents, agent : &mut Agent<T>, withdrawal_coin: Coin<T>, clock: &Clock, ctx: &mut TxContext) {
    let coin_type = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(coin_type);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(withdrawal_coin.value() > 0, EInvalidCoin);
    assert!(withdrawal_coin.value() > agent.min_withdraw_limit && withdrawal_coin.value() < agent.max_withdraw_limit, ENotInAgentWithdrawalRange);
    let amount = withdrawal_coin.value();
    let agent_id = object::id_address(agent);
    let withdraw_request = WithdrawRequest<T>{
        id: object::new(ctx),
        amount,
        user: ctx.sender(),
        agent_id,
        coin_type,
        status: WithdrawStatus::Pending,
        request_time: clock.timestamp_ms(),
        status_time: option::none<u64>()
    };
    let coin_balance = withdrawal_coin.into_balance();
    agent.balance.join(coin_balance);
    let request_id = *withdraw_request.id.as_inner();
    agent.pending_withdrawals.push_back(request_id);
    agent.total_pending_withdrawals = agent.total_pending_withdrawals + 1;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount + amount;

    event::emit(WithdrawalRequestEvent{
        request_id,
        agent_id,
        amount,
        user: ctx.sender(),
        coin_type,
        status: WithdrawStatus::Pending,
        time: clock.timestamp_ms()
    });
    transfer::share_object(withdraw_request);
}

public fun deposit_requests<T>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T>, amount: u64, comment: String , clock: &Clock, ctx: &mut TxContext){
    let coin_type = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(coin_type);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    let agent_id = object::id_address(agent);
    assert!(amount > agent.min_deposit_limit && amount < agent.max_deposit_limit, ENotInAgentDepositRange);
    assert!(amount < agent.balance.value(), ENotEnoughAgentBalance);
    let deposit_request = DepositRequest<T>{
        id: object::new(ctx),
        amount,
        agent_id,
        user: ctx.sender(),
        coin_type,
        comment,
        status: DepositStatus::Pending,
        request_time: clock.timestamp_ms(),
        status_time: option::none<u64>(),
    };
    let request_id = *deposit_request.id.as_inner();
    agent.pending_deposits.push_back(request_id);
    agent.total_pending_deposits = agent.total_pending_deposits + 1;
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount + amount;

    event::emit(DepositRequestEvent{
        request_id,
        agent_id,
        amount,
        user: ctx.sender(),
        coin_type,
        comment,
        status: DepositStatus::Pending,
        time: clock.timestamp_ms()
    });
    transfer::share_object(deposit_request);
}

public fun approve_withdrawal<T>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T>, withdraw_request: &mut WithdrawRequest<T>, clock: &Clock, ctx: &mut TxContext) {
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(withdraw_request.status == WithdrawStatus::Pending, ENotInvalidRequest);
    withdraw_request.status = WithdrawStatus::Completed;
    withdraw_request.status_time = option::some(clock.timestamp_ms());
    agent.total_successful_withdrawals_amount = agent.total_successful_withdrawals_amount + withdraw_request.amount;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount - withdraw_request.amount;
    agent.total_successful_withdrawals = agent.total_successful_withdrawals + 1;
    agent.total_pending_withdrawals = agent.total_pending_withdrawals - 1;
    let request_id = *withdraw_request.id.as_inner();
    agent.successful_withdrawals.push_back(request_id);
    event::emit(WithdrawalApprovedEvent{
        request_id,
        agent_id: object::id_address(agent),
        amount: withdraw_request.amount,
        user: withdraw_request.user,
        coin_type: withdraw_request.coin_type,
        status: WithdrawStatus::Completed,
        time: clock.timestamp_ms(),
    });
}

public fun approve_deposits<T>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T>, deposit_request: &mut DepositRequest<T>, clock: &Clock, ctx: &mut TxContext){
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_request.status == DepositStatus::Pending, ENotInvalidRequest);
    assert!(agent.balance.value() >= deposit_request.amount, ENotEnoughAgentBalance);
    let deposit_coin = coin::take(&mut agent.balance, deposit_request.amount, ctx);
    transfer::public_transfer(deposit_coin, deposit_request.user);
    deposit_request.status = DepositStatus::Completed;
    deposit_request.status_time = option::some(clock.timestamp_ms());
    agent.total_successful_deposits_amount = agent.total_successful_deposits_amount + deposit_request.amount;
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount - deposit_request.amount;
    agent.total_successful_deposits = agent.total_successful_deposits + 1;
    agent.total_pending_deposits = agent.total_pending_deposits - 1;
    let request_id = *deposit_request.id.as_inner();
    remove_id_from_vec(&mut agent.pending_deposits, request_id);
    agent.successful_deposits.push_back(request_id);

    event::emit(DepositApprovedEvent{
        request_id,
        agent_id: object::id_address(agent),
        amount: deposit_request.amount,
        user: deposit_request.user,
        coin_type: deposit_request.coin_type,
        status: DepositStatus::Completed,
        time: clock.timestamp_ms(),
    });
}    

public fun cancel_deposits<T>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T>, deposit_request: &mut DepositRequest<T>, clock: &Clock, ctx: &mut TxContext){
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_request.status == DepositStatus::Pending, ENotInvalidRequest);
    deposit_request.status = DepositStatus::Cancelled;
    deposit_request.status_time = option::some(clock.timestamp_ms());
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount - deposit_request.amount;
    agent.total_unsuccessful_deposits = agent.total_successful_deposits + 1;
    agent.total_pending_deposits = agent.total_pending_deposits - 1;
    let request_id = *deposit_request.id.as_inner();
    remove_id_from_vec(&mut agent.pending_deposits, request_id);
    agent.unsuccessful_deposits.push_back(request_id);
    event::emit(DepositCancelledEvent{
        request_id,
        agent_id: object::id_address(agent),
        amount: deposit_request.amount,
        user: deposit_request.user,
        coin_type: deposit_request.coin_type,
        status: DepositStatus::Cancelled,
        time: clock.timestamp_ms(),
    });
}

#[allow(lint(self_transfer))]
public fun agent_withdraw_balance<T>(payfrica_agents: &mut PayfricaAgents,agent: &mut Agent<T>, amount: u64, ctx: &mut TxContext) {
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(agent.balance.value() - agent.total_pending_withdrawals_amount - agent.total_pending_deposits_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());
}

public fun get_all_valid_agent_types(payfrica_agents: &PayfricaAgents): vector<TypeName> {
    payfrica_agents.valid_types
}

public fun get_all_valid_agents<T>(payfrica_agents: &PayfricaAgents): vector<address>{
    let type_name = type_name::get<T>();
    *payfrica_agents.agents.borrow(type_name)
}

public fun set_agent_deposit_limit<T>(cap : &Publisher, agent: &mut Agent<T>, min_amount: u64, max_amount: u64){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    
    agent.min_deposit_limit = min_amount;
    agent.max_deposit_limit = max_amount;

    event::emit(SetAgentDepositLimitEvent{
        agent_id: object::id_address(agent),
        agent_type: type_name::get<T>(),
        min_deposit_limit: min_amount,
        max_deposit_limit: max_amount
    });
}

public fun set_agent_withdrawal_limit<T>(cap : &Publisher, agent: &mut Agent<T>, min_amount: u64, max_amount: u64){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    
    agent.min_withdraw_limit = min_amount;
    agent.max_withdraw_limit = max_amount;

    event::emit(SetAgentWithdrawalLimitEvent{
        agent_id: object::id_address(agent),
        agent_type: type_name::get<T>(),
        min_withdraw_limit: min_amount,
        max_withdraw_limit: max_amount
    });
}

public fun add_agent_balance<T>(payfrica_agents: &PayfricaAgents,agent: &mut Agent<T>, deposit_coin: Coin<T>, clock: &Clock, ctx: &mut TxContext){
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    assert!(deposit_coin.value() > agent.min_deposit_limit && deposit_coin.value() < agent.max_deposit_limit, ENotInAgentDepositRange);
    // let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.balance.join(coin_balance);

    event::emit(AddAgentBalanceEvent{
        agent_id: object::id_address(agent),
        amount: agent.balance.value(),
        sender: ctx.sender(),
        coin_type: type_name,
        time: clock.timestamp_ms()
    });
}

public fun add_agent_balance_admin<T>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T>, deposit_coin: Coin<T>, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    // let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.balance.join(coin_balance);

    event::emit(AddAgentBalanceEvent{
        agent_id: object::id_address(agent),
        amount: agent.balance.value(),
        sender: ctx.sender(),
        coin_type: type_name,
        time: clock.timestamp_ms()
    });
}

#[allow(lint(self_transfer))]
public fun withdraw_agent_balance_admin<T>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T>, amount: u64, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(agent.balance.value() - agent.total_pending_withdrawals_amount - agent.total_pending_deposits_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());

    event::emit(AgentBalanceWithdrawEvent{
        agent_id: object::id_address(agent),
        amount: agent.balance.value(),
        sender: ctx.sender(),
        coin_type: type_name,
        time: clock.timestamp_ms()
    });
}

public fun get_agent_pending_deposits<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.pending_deposits
}

public fun get_agent_pending_withdrawal<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.pending_withdrawals
}

public fun get_agent_unsuccessful_deposits<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.unsuccessful_deposits
}

// public fun get_agent_unsuccessful_withdrawals<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
//     let type_name = type_name::get<T>();
//     let agents = payfrica_agents.agents.borrow(type_name);
//     assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
//     agent.unsuccessful_withdrawals
// }

public fun get_agent_successful_deposits<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.successful_deposits
}

public fun get_agent_successful_withdrawals<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.successful_withdrawals
}

public fun get_agent_total_pending_deposits_amount<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): u64{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.total_pending_deposits_amount
}

public fun get_agent_total_pending_withdrawals_amount<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): u64{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.total_pending_withdrawals_amount
}

public fun get_agent_balance<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): u64{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.balance.value()
}

public fun get_agent_total_transactional_balance<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): u64{
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.balance.value() - agent.total_pending_withdrawals_amount - agent.total_pending_deposits_amount
}

public fun get_agent_withdrawal_limits<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): (u64, u64){
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    (agent.min_withdraw_limit, agent.max_withdraw_limit)
}

public fun get_agent_deposit_limits<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): (u64, u64){
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    (agent.min_deposit_limit, agent.max_deposit_limit)
}

fun remove_id_from_vec(vec: &mut vector<ID>, id: ID){
    let mut i = 0;
    while(i < vec.length()){
        if(vec.borrow(i) == id){
            vec.remove(i);
            break
        };
        i = i + 1;
    };
}

#[test_only]
public fun call_init(ctx: &mut TxContext){
    let otw = AGENTS{};
    init(otw, ctx);
}


