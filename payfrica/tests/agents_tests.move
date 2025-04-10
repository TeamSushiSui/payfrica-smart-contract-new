#[test_only]
module payfrica::agents_test;

use payfrica::{
    agents::{Self, Agent, PayfricaAgents},
    ngnc::{Self, NGNC, Reserve},
    usdc::{Self, USDC},
    pool_new::{Self, Payfrica, Pool},
};

use sui::{
    test_scenario::{Self as ts, Scenario},
    coin::{Self, Coin, TreasuryCap},
    test_utils::assert_eq,
    package::{Self, Publisher},
};

const Admin: address = @0xa;
const Agent1: address = @0xb;



fun call_init_ngnc(scenario: &mut Scenario) {
    ngnc::call_init(scenario.ctx());
}

fun call_init_usdc(scenario: &mut Scenario){
    usdc::call_init(scenario.ctx());
}

fun call_init_pool(scenario: &mut Scenario){
    pool_new::call_init(scenario.ctx());
}

fun call_init_agents(scenario: &mut Scenario){
    agents::call_init(scenario.ctx());
}

fun call_create_reserve_ngnc(scenario: &mut Scenario){
    ngnc::create_reserve<USDC>(scenario.ctx());
}

fun call_mint_usdc(scenario: &mut Scenario, amount: u64) {
    let mut treasury_cap = scenario.take_from_sender<TreasuryCap<USDC>>();
    usdc::mint(&mut treasury_cap, amount, scenario.ctx().sender() , scenario.ctx());
    scenario.return_to_sender(treasury_cap);
}

fun call_mint_ngnc(scenario: &mut Scenario, reserve_coin: Coin<USDC>, conversion_rate: u64) {
    let mut reserve = scenario.take_shared<Reserve<USDC>>();
    let mut pool = scenario.take_shared<Pool<NGNC>>();
    let mut treasury_cap = scenario.take_from_sender<TreasuryCap<NGNC>>();
    ngnc::mint_to_pool<USDC>(&mut reserve, &mut pool, reserve_coin, &mut treasury_cap, conversion_rate, scenario.ctx());
    scenario.return_to_sender(treasury_cap);
    ts::return_shared(reserve);
    ts::return_shared(pool);
}

fun call_get_usdc(scenario: &mut Scenario) : Coin<USDC> {
    scenario.take_from_sender<Coin<USDC>>()
}

fun call_create_pool<T>(scenario: &mut Scenario) {
    let cap = scenario.take_from_sender<Publisher>();
    pool_new::create_new_pool<T>(&cap, scenario.ctx());
    scenario.return_to_sender(cap);
}

fun call_create_agent(scenario: &mut Scenario) {
    let cap = scenario.take_from_sender<Publisher>();
    let mut payfrica_agents = scenario.take_shared<PayfricaAgents>();
    agents::create_agent<NGNC>(&cap,&mut payfrica_agents, Agent1, scenario.ctx());
    ts::return_shared(payfrica_agents);
    scenario.return_to_sender(cap);
}

fun call_add_valid_agent_types(scenario: &Scenario){
    let cap = scenario.take_from_sender<Publisher>();
    let mut payfrica_agents = scenario.take_shared<PayfricaAgents>();
    agents::add_valid_agent_type<NGNC>(&cap, &mut payfrica_agents);
    ts::return_shared(payfrica_agents);
    scenario.return_to_sender(cap);
}

fun call_set_agent_withdrawal_limit(scenario: &Scenario, min_withdrawal_limit: u64, max_withdrawal_limit: u64) {
    let cap = scenario.take_from_sender<Publisher>();
    let mut agent = scenario.take_shared<Agent<NGNC>>();
    agents::set_agent_withdrawal_limit<NGNC>(&cap, &mut agent, min_withdrawal_limit, max_withdrawal_limit);
    ts::return_shared(agent);
    scenario.return_to_sender(cap);
}

fun call_set_agent_deposit_limit(scenario: &Scenario, min_deposit_limit: u64, max_deposit_limit: u64) {
    let cap = scenario.take_from_sender<Publisher>();
    let mut agent = scenario.take_shared<Agent<NGNC>>();
    agents::set_agent_deposit_limit<NGNC>(&cap, &mut agent, min_deposit_limit, max_deposit_limit);
    ts::return_shared(agent);
    scenario.return_to_sender(cap);
}

#[test]
fun test_call_init_agents() {
    let mut scenario = ts::begin(Admin);
    call_init_agents(&mut scenario);
    scenario.end();
}

#[test]
fun test_call_init_ngnc() {
    let mut scenario = ts::begin(Admin);
    call_init_ngnc(&mut scenario);
    scenario.end();
}

#[test]
fun test_call_init_usdc() {
    let mut scenario = ts::begin(Admin);
    call_init_usdc(&mut scenario);
    scenario.end();
}


#[test]
fun test_call_init_pool() {
    let mut scenario = ts::begin(Admin);
    call_init_pool(&mut scenario);
    scenario.end();
}

#[test]
fun test_create_reserve_ngnc() {
    let mut scenario = ts::begin(Admin);
    call_init_ngnc(&mut scenario);
    scenario.next_tx(Admin);
    call_create_reserve_ngnc(&mut scenario);
    scenario.end();
}

#[test]
fun test_create_pool_ngnc() {
    let mut scenario = ts::begin(Admin);
    call_init_pool(&mut scenario);
    scenario.next_tx(Admin);
    call_create_pool<NGNC>(&mut scenario);
    scenario.end();
}

#[test]
fun test_mint_usdc() {
    let mut scenario = ts::begin(Admin);
    call_init_usdc(&mut scenario);
    scenario.next_tx(Admin);
    call_mint_usdc(&mut scenario, 1000000000);
    scenario.end();
}

#[test]
fun test_mint_ngnc() {
    let mut scenario = ts::begin(Admin);
    call_init_usdc(&mut scenario);
    scenario.next_tx(Admin);
    call_mint_usdc(&mut scenario, 1000000000);
    scenario.next_tx(Admin);
    let usdc_coin = call_get_usdc(&mut scenario);
    scenario.next_tx(Admin);
    call_init_pool(&mut scenario);
    scenario.next_tx(Admin);
    call_create_pool<NGNC>(&mut scenario);
    scenario.next_tx(Admin);
    call_init_ngnc(&mut scenario);
    scenario.next_tx(Admin);
    call_create_reserve_ngnc(&mut scenario);
    scenario.next_tx(Admin);
    call_mint_ngnc(&mut scenario, usdc_coin, 1500000000);
    scenario.end();
}

#[test]
fun test_add_valid_agent_types() {
    let mut scenario = ts::begin(Admin);
    call_init_agents(&mut scenario);
    scenario.next_tx(Admin);
    call_add_valid_agent_types(&scenario);
    scenario.end();
}

#[test]
fun test_create_agent() {
    let mut scenario = ts::begin(Admin);
    call_init_agents(&mut scenario);
    scenario.next_tx(Admin);
    call_add_valid_agent_types(&scenario);
    scenario.next_tx(Admin);
    call_create_agent(&mut scenario);
    scenario.end();
}

#[test]
fun test_set_agent_withdrawal_limit() {
    let mut scenario = ts::begin(Admin);
    call_init_agents(&mut scenario);
    scenario.next_tx(Admin);
    call_add_valid_agent_types(&scenario);
    scenario.next_tx(Admin);
    call_create_agent(&mut scenario);
    scenario.next_tx(Admin);
    call_set_agent_withdrawal_limit(&scenario, 1000000000, 100000000000);
    scenario.end();
}

#[test]
fun test_set_agent_deposit_limit() {
    let mut scenario = ts::begin(Admin);
    call_init_agents(&mut scenario);
    scenario.next_tx(Admin);
    call_add_valid_agent_types(&scenario);
    scenario.next_tx(Admin);
    call_create_agent(&mut scenario);
    scenario.next_tx(Admin);
    call_set_agent_deposit_limit(&scenario, 1000000000, 100000000000);
    scenario.end();
}