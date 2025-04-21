module payfrica::bridge_agents;
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
    ascii::{String as AsciiString}
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

public struct BRIDGE_AGENTS has drop{}

public struct PayfricaAgents has key{
    id: UID,
    agents: Table<AsciiString, vector<address>>, 
    valid_types: vector<AsciiString>,
}

public struct WithdrawRequest<phantom T, phantom T2> has key, store{
    id: UID,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    agent_id: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: WithdrawStatus,
    request_time: u64,
    status_time: Option<u64>
}
public struct DepositRequest<phantom T1, phantom T2> has key, store{
    id: UID,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    agent_id: address,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: DepositStatus,
    request_time: u64,
    status_time: Option<u64>,
}

public struct Agent<phantom T0, phantom T1> has key, store{
    id: UID,
    addr: address,
    base_balance: Balance<T0>,
    sui_coin_balance: Balance<T1>,
    base_coin_type: TypeName,
    sui_coin_type: TypeName,
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
    type_a: TypeName,
    type_b: TypeName
}

public struct ValidAgentTypeAddedEvent has copy, drop{
    type_a: TypeName,
    type_b: TypeName
}

public struct WithdrawalRequestEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: WithdrawStatus,
    time: u64
}
public struct DepositRequestEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: DepositStatus,
    time: u64
}

public struct WithdrawalApprovedEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: WithdrawStatus,
    time: u64
}

public struct WithdrawalCancelledEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: WithdrawStatus,
    time: u64
}

public struct DepositApprovedEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: DepositStatus,
    time: u64
}

public struct DepositCancelledEvent has copy, drop{
    request_id: ID,
    agent_id: address,
    input_amount: u64,
    output_amount: u64,
    conversion_rate: u64,
    conversion_rate_scale_decimal: u8,
    user: address,
    input_coin_type: TypeName,
    output_coin_type: TypeName,
    status: DepositStatus,
    time: u64
}

public struct SetAgentWithdrawalLimitEvent has copy, drop{
    agent_id: address,
    type_a: TypeName,
    type_b: TypeName,
    min_withdraw_limit: u64,
    max_withdraw_limit: u64
}
public struct SetAgentDepositLimitEvent has copy, drop{
    agent_id: address,
    type_a: TypeName,
    type_b: TypeName,
    min_deposit_limit: u64,
    max_deposit_limit: u64
}

public struct AddAgentBaseBalanceEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    type_a: TypeName,
    type_b: TypeName,
    time: u64
}

public struct AddAgentSuiCoinBalanceEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    type_a: TypeName,
    type_b: TypeName,
    time: u64
}

public struct AgentBaseBalanceWithdrawEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    type_a: TypeName,
    type_b: TypeName,
    time: u64
}

public struct AgentSuiCoinBalanceWithdrawEvent has copy, drop{
    agent_id: address,
    amount: u64,
    sender: address,
    type_a: TypeName,
    type_b: TypeName,
    time: u64
}

fun init(otw: BRIDGE_AGENTS, ctx: &mut TxContext) {
    let publisher : Publisher = package::claim(otw, ctx);
    let payfrica_agents = PayfricaAgents {
        id: object::new(ctx),
        agents: table::new<AsciiString, vector<address>>(ctx),
        valid_types: vector::empty<AsciiString>(),
    };
    transfer::share_object(payfrica_agents);
    transfer::public_transfer(publisher, ctx.sender());
}

public fun create_agent<T1, T2>(cap : &Publisher,payfrica_agents: &mut PayfricaAgents, agent_addr: address, ctx: &mut TxContext) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    assert!(payfrica_agents.valid_types.contains(&coin_type_t1_string), EInvalidAgentType);
    let agent = Agent {
        id: object::new(ctx),
        addr: agent_addr,
        base_balance: balance::zero<T1>(),
        sui_coin_balance: balance::zero<T2>(),
        base_coin_type: type_name::get<T1>(),
        sui_coin_type: type_name::get<T2>(),
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
    let agents = payfrica_agents.agents.borrow_mut(coin_type_t1_string);
    agents.push_back(object::id_address(&agent));
    event::emit(AgentAddedEvent{
        agent_id: object::id_address(&agent),
        agent: agent_addr,
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>()
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

public fun add_valid_agent_type<T1, T2>(cap : &Publisher,payfrica_agents: &mut PayfricaAgents) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    assert!(!payfrica_agents.valid_types.contains(&coin_type_t1_string), EInvalidAgentType);
    payfrica_agents.valid_types.push_back(coin_type_t1_string);
    payfrica_agents.agents.add(coin_type_t1_string, vector::empty<address>());
    event::emit(ValidAgentTypeAddedEvent{
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>()
    });
}

public fun withdrawal_request<T1, T2>(payfrica_agents: &mut PayfricaAgents, agent : &mut Agent<T1, T2>, conversion_rate: u64, conversion_rate_scale_decimal: u8, withdrawal_coin: Coin<T2>, clock: &Clock, ctx: &mut TxContext) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(withdrawal_coin.value() > 0, EInvalidCoin);
    let conversion_r_scale_factor = 10u64.pow(conversion_rate_scale_decimal);
    let coin_t2_amount = (withdrawal_coin.value() * conversion_rate) / (conversion_r_scale_factor);
    assert!(coin_t2_amount > agent.min_withdraw_limit && coin_t2_amount < agent.max_withdraw_limit, ENotInAgentWithdrawalRange);
    assert!(coin_t2_amount < agent.base_balance.value(), ENotEnoughAgentBalance);
    let amount = withdrawal_coin.value();
    let agent_id = object::id_address(agent);
    let withdraw_request = WithdrawRequest<T1, T2>{
        id: object::new(ctx),
        input_amount: amount,
        output_amount: coin_t2_amount,
        conversion_rate,
        conversion_rate_scale_decimal,
        user: ctx.sender(),
        agent_id,
        input_coin_type: type_name::get<T2>(),
        output_coin_type: type_name::get<T1>(),
        status: WithdrawStatus::Pending,
        request_time: clock.timestamp_ms(),
        status_time: option::none<u64>()
    };
    let coin_balance = withdrawal_coin.into_balance();
    agent.sui_coin_balance.join(coin_balance);
    let request_id = *withdraw_request.id.as_inner();
    agent.pending_withdrawals.push_back(request_id);
    agent.total_pending_withdrawals = agent.total_pending_withdrawals + 1;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount + coin_t2_amount;

    event::emit(WithdrawalRequestEvent{
        request_id,
        agent_id,
        input_amount: amount,
        output_amount: coin_t2_amount,
        conversion_rate,
        conversion_rate_scale_decimal,
        user: ctx.sender(),
        input_coin_type: type_name::get<T2>(),
        output_coin_type: type_name::get<T2>(),
        status: WithdrawStatus::Pending,
        time: clock.timestamp_ms()
    });
    transfer::share_object(withdraw_request);
}

public fun deposit_requests<T1,T2>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T1,T2>, coin_t1_amount: u64, conversion_rate: u64, conversion_rate_scale_decimal: u8, clock: &Clock, ctx: &mut TxContext){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    let agent_id = object::id_address(agent);
    let conversion_r_scale_factor = 10u64.pow(conversion_rate_scale_decimal);
    let coin_t2_amount = (coin_t1_amount * conversion_rate) / (conversion_r_scale_factor);
    assert!(coin_t2_amount > agent.min_deposit_limit && coin_t2_amount < agent.max_deposit_limit, ENotInAgentDepositRange);
    assert!(coin_t2_amount < agent.sui_coin_balance.value(), ENotEnoughAgentBalance);
    let deposit_request = DepositRequest<T1, T2>{
        id: object::new(ctx),
        input_amount: coin_t1_amount,
        output_amount: coin_t2_amount,
        conversion_rate,
        conversion_rate_scale_decimal,
        agent_id,
        user: ctx.sender(),
        input_coin_type: type_name::get<T1>(),
        output_coin_type: type_name::get<T2>(),
        status: DepositStatus::Pending,
        request_time: clock.timestamp_ms(),
        status_time: option::none<u64>(),
    };
    let request_id = *deposit_request.id.as_inner();
    agent.pending_deposits.push_back(request_id);
    agent.total_pending_deposits = agent.total_pending_deposits + 1;
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount + coin_t2_amount;

    event::emit(DepositRequestEvent{
        request_id,
        agent_id,
        input_amount: coin_t1_amount,
        output_amount: coin_t2_amount,
        conversion_rate,
        conversion_rate_scale_decimal,
        user: ctx.sender(),
        input_coin_type: type_name::get<T1>(),
        output_coin_type: type_name::get<T2>(),
        status: DepositStatus::Pending,
        time: clock.timestamp_ms()
    });
    transfer::share_object(deposit_request);
}

public fun approve_withdrawal<T1,T2>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T1,T2>, withdraw_request: &mut WithdrawRequest<T1,T2>, clock: &Clock, ctx: &mut TxContext) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(withdraw_request.status == WithdrawStatus::Pending, ENotInvalidRequest);
    let output_coin = coin::take(&mut agent.base_balance, withdraw_request.output_amount, ctx);
    withdraw_request.status = WithdrawStatus::Completed;
    withdraw_request.status_time = option::some(clock.timestamp_ms());
    agent.total_successful_withdrawals_amount = agent.total_successful_withdrawals_amount + withdraw_request.output_amount;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount - withdraw_request.output_amount;
    agent.total_successful_withdrawals = agent.total_successful_withdrawals + 1;
    agent.total_pending_withdrawals = agent.total_pending_withdrawals - 1;
    let request_id = *withdraw_request.id.as_inner();
    agent.successful_withdrawals.push_back(request_id);
    transfer::public_transfer(output_coin, agent.addr);
    event::emit(WithdrawalApprovedEvent{
        request_id,
        agent_id: object::id_address(agent),
        input_amount: withdraw_request.input_amount,
        output_amount: withdraw_request.output_amount,
        conversion_rate: withdraw_request.conversion_rate,
        conversion_rate_scale_decimal: withdraw_request.conversion_rate_scale_decimal,
        user: withdraw_request.user,
        input_coin_type: withdraw_request.input_coin_type,
        output_coin_type: withdraw_request.output_coin_type,
        status: WithdrawStatus::Completed,
        time: clock.timestamp_ms(),
    });
    
}


public fun approve_deposits<T1,T2>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T1, T2>, deposit_request: &mut DepositRequest<T1,T2>, input_coin: Coin<T1>, clock: &Clock, ctx: &mut TxContext){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_request.status == DepositStatus::Pending, ENotInvalidRequest);
    assert!(agent.sui_coin_balance.value() >= deposit_request.output_amount, ENotEnoughAgentBalance);
    let deposit_coin = coin::take(&mut agent.sui_coin_balance, deposit_request.output_amount, ctx);
    agent.base_balance.join(input_coin.into_balance());
    transfer::public_transfer(deposit_coin, deposit_request.user);
    deposit_request.status = DepositStatus::Completed;
    deposit_request.status_time = option::some(clock.timestamp_ms());
    agent.total_successful_deposits_amount = agent.total_successful_deposits_amount + deposit_request.output_amount;
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount - deposit_request.output_amount;
    agent.total_successful_deposits = agent.total_successful_deposits + 1;
    agent.total_pending_deposits = agent.total_pending_deposits - 1;
    let request_id = *deposit_request.id.as_inner();
    remove_id_from_vec(&mut agent.pending_deposits, request_id);
    agent.successful_deposits.push_back(request_id);

    event::emit(DepositApprovedEvent{
        request_id,
        agent_id: object::id_address(agent),
        input_amount: deposit_request.input_amount,
        output_amount: deposit_request.output_amount,
        conversion_rate: deposit_request.conversion_rate,
        conversion_rate_scale_decimal: deposit_request.conversion_rate_scale_decimal,
        user: deposit_request.user,
        input_coin_type: type_name::get<T1>(),
        output_coin_type: type_name::get<T2>(),
        status: DepositStatus::Completed,
        time: clock.timestamp_ms(),
    });
}    

public fun cancel_deposits<T1, T2>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T1, T2>, deposit_request: &mut DepositRequest<T1, T2>, clock: &Clock, ctx: &mut TxContext){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_request.status == DepositStatus::Pending, ENotInvalidRequest);
    deposit_request.status = DepositStatus::Cancelled;
    deposit_request.status_time = option::some(clock.timestamp_ms());
    agent.total_pending_deposits_amount = agent.total_pending_deposits_amount - deposit_request.output_amount;
    agent.total_unsuccessful_deposits = agent.total_successful_deposits + 1;
    agent.total_pending_deposits = agent.total_pending_deposits - 1;
    let request_id = *deposit_request.id.as_inner();
    remove_id_from_vec(&mut agent.pending_deposits, request_id);
    agent.unsuccessful_deposits.push_back(request_id);
    event::emit(DepositCancelledEvent{
        request_id,
        agent_id: object::id_address(agent),
        input_amount: deposit_request.input_amount,
        output_amount: deposit_request.output_amount,
        conversion_rate: deposit_request.conversion_rate,
        conversion_rate_scale_decimal: deposit_request.conversion_rate_scale_decimal,
        user: deposit_request.user,
        input_coin_type: type_name::get<T1>(),
        output_coin_type: type_name::get<T2>(),
        status: DepositStatus::Cancelled,
        time: clock.timestamp_ms(),
    });
}

#[allow(lint(self_transfer))]
public fun agent_withdraw_sui_coin_balance<T1,T2>(payfrica_agents: &mut PayfricaAgents,agent: &mut Agent<T1, T2>, amount: u64, ctx: &mut TxContext) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(agent.sui_coin_balance.value() - agent.total_pending_deposits_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.sui_coin_balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());
}

#[allow(lint(self_transfer))]
public fun agent_withdraw_base_balance<T1,T2>(payfrica_agents: &mut PayfricaAgents,agent: &mut Agent<T1, T2>, amount: u64, ctx: &mut TxContext) {
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(agent.base_balance.value() - agent.total_pending_withdrawals_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.base_balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());
}


public fun get_all_valid_agent_types(payfrica_agents: &PayfricaAgents): vector<AsciiString> {
    payfrica_agents.valid_types
}

public fun get_all_valid_agents<T1, T2>(payfrica_agents: &PayfricaAgents): vector<address>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    *payfrica_agents.agents.borrow(coin_type_t1_string)
}

public fun set_agent_deposit_limit<T1,T2>(cap : &Publisher, agent: &mut Agent<T1,T2>, min_amount: u64, max_amount: u64){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    
    agent.min_deposit_limit = min_amount;
    agent.max_deposit_limit = max_amount;

    event::emit(SetAgentDepositLimitEvent{
        agent_id: object::id_address(agent),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        min_deposit_limit: min_amount,
        max_deposit_limit: max_amount
    });
}

public fun set_agent_withdrawal_limit<T1,T2>(cap : &Publisher, agent: &mut Agent<T1,T2>, min_amount: u64, max_amount: u64){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    
    agent.min_withdraw_limit = min_amount;
    agent.max_withdraw_limit = max_amount;

    event::emit(SetAgentWithdrawalLimitEvent{
        agent_id: object::id_address(agent),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        min_withdraw_limit: min_amount,
        max_withdraw_limit: max_amount
    });
}

public fun add_agent_base_balance<T1,T2>(payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, deposit_coin: Coin<T1>, clock: &Clock, ctx: &mut TxContext){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    assert!(deposit_coin.value() > agent.min_deposit_limit && deposit_coin.value() < agent.max_deposit_limit, ENotInAgentDepositRange);
    let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.base_balance.join(coin_balance);

    event::emit(AddAgentBaseBalanceEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

public fun add_agent_sui_coin_balance<T1,T2>(payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, deposit_coin: Coin<T2>, clock: &Clock, ctx: &mut TxContext){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    assert!(deposit_coin.value() > agent.min_deposit_limit && deposit_coin.value() < agent.max_deposit_limit, ENotInAgentDepositRange);
    let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.sui_coin_balance.join(coin_balance);

    event::emit(AddAgentSuiCoinBalanceEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

public fun add_agent_base_balance_admin<T1,T2>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, deposit_coin: Coin<T1>, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.base_balance.join(coin_balance);

    event::emit(AddAgentBaseBalanceEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

public fun add_agent_sui_coin_balance_admin<T1,T2>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, deposit_coin: Coin<T2>, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgent);
    assert!(deposit_coin.value() > 0, EInvalidCoin);
    let amount = deposit_coin.value();
    let coin_balance = deposit_coin.into_balance();
    agent.sui_coin_balance.join(coin_balance);

    event::emit(AddAgentSuiCoinBalanceEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

#[allow(lint(self_transfer))]
public fun withdraw_agent_base_balance_admin<T1,T2>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, amount: u64, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(agent.base_balance.value() - agent.total_pending_withdrawals_amount - agent.total_pending_deposits_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.base_balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());

    event::emit(AgentBaseBalanceWithdrawEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

#[allow(lint(self_transfer))]
public fun withdraw_agent_sui_coin_balance_admin<T1,T2>(cap : &Publisher,payfrica_agents: &PayfricaAgents,agent: &mut Agent<T1,T2>, amount: u64, clock: &Clock, ctx: &mut TxContext){
    assert!(cap.from_module<PayfricaAgents>(), ENotAuthorized);
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(agent.sui_coin_balance.value() - agent.total_pending_withdrawals_amount - agent.total_pending_deposits_amount >= amount, EInvalidBalance);
    let withdraw_coin = coin::take(&mut agent.sui_coin_balance, amount, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());

    event::emit(AgentSuiCoinBalanceWithdrawEvent{
        agent_id: object::id_address(agent),
        amount,
        sender: ctx.sender(),
        type_a: type_name::get<T1>(),
        type_b: type_name::get<T2>(),
        time: clock.timestamp_ms()
    });
}

public fun get_agent_pending_deposits<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): vector<ID>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.pending_deposits
}

public fun get_agent_pending_withdrawal<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): vector<ID>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.pending_withdrawals
}

public fun get_agent_unsuccessful_deposits<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): vector<ID>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.unsuccessful_deposits
}

// public fun get_agent_unsuccessful_withdrawals<T>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T>): vector<ID>{
//     let type_name = type_name::get<T>();
//     let agents = payfrica_agents.agents.borrow(type_name);
//     assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
//     agent.unsuccessful_withdrawals
// }

public fun get_agent_successful_deposits<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): vector<ID>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.successful_deposits
}

public fun get_agent_successful_withdrawals<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): vector<ID>{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.successful_withdrawals
}

public fun get_agent_total_pending_deposits_amount<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.total_pending_deposits_amount
}

public fun get_agent_total_pending_withdrawals_amount<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.total_pending_withdrawals_amount
}

public fun get_agent_base_balance<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.base_balance.value()
}

public fun get_agent_sui_coin_balance<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.sui_coin_balance.value()
}

public fun get_agent_total_transactional_withdrawal_balance<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.base_balance.value() - agent.total_pending_withdrawals_amount
}

public fun get_agent_total_transactional_deposit_balance<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): u64{
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    agent.sui_coin_balance.value() - agent.total_pending_deposits_amount
}

public fun get_agent_withdrawal_limits<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): (u64, u64){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    (agent.min_withdraw_limit, agent.max_withdraw_limit)
}

public fun get_agent_deposit_limits<T1,T2>(payfrica_agents: &PayfricaAgents, agent: &mut Agent<T1,T2>): (u64, u64){
    let mut coin_type_t1_string = *type_name::get<T1>().borrow_string();
    let coin_type_t2_string = *type_name::get<T2>().borrow_string();
    coin_type_t1_string.append(coin_type_t2_string);
    let agents = payfrica_agents.agents.borrow(coin_type_t1_string);
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
    let otw = BRIDGE_AGENTS{};
    init(otw, ctx);
}


