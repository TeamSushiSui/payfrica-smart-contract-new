module payfrica::agents;
use sui::{
    coin::{Self,Coin},
    balance::{Self, Balance},
    table::{Self, Table},
    package::{Self, Publisher},
    event
};

use std::type_name::{Self, TypeName};

const EInvalidAgentType: u64 = 1;
const ENotAuthorized : u64 = 0;
const EInvalidCoin: u64 = 2;
const EInvalidAgent: u64 = 3;
const EInvalidBalance: u64 = 4;

public enum WithdrawStatus has copy, drop, store{
    Pending,
    Completed,
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
    coin_type: TypeName,
    status: WithdrawStatus,
}

public struct Agent<phantom T> has key, store{
    id: UID,
    addr: address,
    balance: Balance<T>,
    coin_type: TypeName,
    pending_withdrawals: Table<address, WithdrawRequest<T>>,
    successful_withdrawals: vector<WithdrawRequest<T>>,
    total_successful_withdrawals: u64,
    total_pending_withdrawals: u64,
    total_successful_withdrawals_amount: u64,
    total_pending_withdrawals_amount: u64,

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
    request_id: address,
    agendt_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: WithdrawStatus,
}

public struct WithdrawalApprovedEvent has copy, drop{
    request_id: address,
    agent_id: address,
    amount: u64,
    user: address,
    coin_type: TypeName,
    status: WithdrawStatus,
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
        pending_withdrawals: table::new<address, WithdrawRequest<T>>(ctx),
        successful_withdrawals: vector::empty<WithdrawRequest<T>>(),
        total_successful_withdrawals: 0,
        total_pending_withdrawals: 0,
        total_successful_withdrawals_amount: 0,
        total_pending_withdrawals_amount: 0,
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

// fun check_valid_agent_type(valid_types: &vector<TypeName>, type_name: TypeName): bool {
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
    event::emit(ValidAgentTypeAddedEvent{
        agent_type: type_name,
    });
}

public fun withdraw<T>(agent : &mut Agent<T>, withdrawal_coin: Coin<T>, ctx: &mut TxContext) {
    assert!(withdrawal_coin.value() > 0, EInvalidCoin);
    let coin_type = type_name::get<T>();
    let amount = withdrawal_coin.value();
    let withdraw_request = WithdrawRequest<T>{
        id: object::new(ctx),
        amount,
        user: ctx.sender(),
        coin_type,
        status: WithdrawStatus::Pending,
    };
    let coin_balance = withdrawal_coin.into_balance();
    agent.balance.join(coin_balance);
    let request_id = object::id_address(&withdraw_request);
    agent.pending_withdrawals.add(request_id, withdraw_request);
    agent.total_pending_withdrawals = agent.total_pending_withdrawals + 1;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount + amount;

    event::emit(WithdrawalRequestEvent{
        request_id,
        agendt_id: object::id_address(agent),
        amount,
        user: ctx.sender(),
        coin_type,
        status: WithdrawStatus::Pending,
    });
}

public fun approve_withdrawal<T>(payfrica_agents: &mut PayfricaAgents, agent: &mut Agent<T>, request_id: address, ctx: &mut TxContext) {
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    let mut withdraw_request = agent.pending_withdrawals.remove(request_id);
    assert!(withdraw_request.status == WithdrawStatus::Pending, ENotAuthorized);
    withdraw_request.status = WithdrawStatus::Completed;
    agent.total_successful_withdrawals_amount = agent.total_successful_withdrawals_amount + withdraw_request.amount;
    agent.total_pending_withdrawals_amount = agent.total_pending_withdrawals_amount - withdraw_request.amount;
    agent.total_successful_withdrawals = agent.total_successful_withdrawals + 1;
    agent.total_pending_withdrawals = agent.total_pending_withdrawals - 1;

    event::emit(WithdrawalApprovedEvent{
        request_id,
        agent_id: object::id_address(agent),
        amount: withdraw_request.amount,
        user: withdraw_request.user,
        coin_type: withdraw_request.coin_type,
        status: WithdrawStatus::Completed,
    });

    agent.successful_withdrawals.push_back(withdraw_request);
}

#[allow(lint(self_transfer))]
public fun agent_withdraw_balance<T>(payfrica_agents: &mut PayfricaAgents,agent: &mut Agent<T>, amount: u64, ctx: &mut TxContext) {
    let type_name = type_name::get<T>();
    let agents = payfrica_agents.agents.borrow(type_name);
    assert!(agents.contains(&object::id_address(agent)), EInvalidAgentType);
    assert!(ctx.sender() == agent.addr, EInvalidAgent);
    assert!(agent.balance.value() - agent.total_pending_withdrawals_amount >= amount, EInvalidBalance);
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

