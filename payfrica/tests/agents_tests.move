#[test_only]
module payfrica::payfrica_tests;

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
    clock,
};

const Admin: address = @0xa;
const Agent1: address = @0xb;
const UsdcToNgncRate: u64 = 1500000;
const ConversionRateDecimal: u8 = 3;

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

fun call_mint_ngnc(scenario: &mut Scenario, pool: &mut Pool<NGNC>, reserve_coin: Coin<USDC>) {
    let mut reserve = scenario.take_shared<Reserve<USDC>>();
    // let mut pool = scenario.take_shared<Pool<NGNC>>();
    let mut treasury_cap = scenario.take_from_sender<TreasuryCap<NGNC>>();
    ngnc::mint_to_pool<USDC>(&mut reserve, pool, reserve_coin, &mut treasury_cap, UsdcToNgncRate, scenario.ctx());
    scenario.return_to_sender(treasury_cap);
    ts::return_shared(reserve);
    // ts::return_shared(pool);
}

fun call_get_usdc(scenario: &Scenario) : Coin<USDC> {
    scenario.take_from_sender<Coin<USDC>>()
}

fun call_get_ngnc(scenario: &Scenario) : Coin<NGNC> {
    scenario.take_from_sender<Coin<NGNC>>()
}

fun call_swap_a_2_b<T1, T2>(pool_a: &mut Pool<T1>, pool_b: &mut Pool<T2>, scenario: &mut Scenario, coin_a: Coin<T1>) {
    // let mut ngnc_pool = scenario.take_shared<Pool<NGNC>>();
    // let mut usdc_pool = scenario.take_shared<Pool<USDC>>();

    pool_a.convert_a_to_b<T1, T2>(pool_b, coin_a,  UsdcToNgncRate, 6, ConversionRateDecimal, scenario.ctx());
    // ts::return_shared(ngnc_pool);
    // ts::return_shared(usdc_pool);
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

fun call_withdraw(scenario: &mut Scenario, agent: &mut Agent<NGNC>, withdrawal_coin: Coin<NGNC>) {
    let mut test_clock = clock::create_for_testing(scenario.ctx());
    test_clock.increment_for_testing(1);
    agents::withdraw<NGNC>(agent, withdrawal_coin, &test_clock, scenario.ctx());
    test_clock.destroy_for_testing();
}

fun call_add_agent_balance_admin(scenario: &mut Scenario, mut agent: Agent<NGNC>, deposit_coin: Coin<NGNC>) {
    let cap = scenario.take_from_sender<Publisher>();
    let payfrica_agents = scenario.take_shared<PayfricaAgents>();
    let mut test_clock = clock::create_for_testing(scenario.ctx());
    test_clock.increment_for_testing(1);
    agents::add_agent_balance_admin<NGNC>(&cap, &payfrica_agents, &mut agent, deposit_coin, &test_clock, scenario.ctx());
    test_clock.destroy_for_testing();
    ts::return_shared(payfrica_agents);
    ts::return_shared(agent);
    scenario.return_to_sender(cap);
}

fun call_get_agent(scenario: &Scenario) : Agent<NGNC>{
    scenario.take_shared<Agent<NGNC>>()
}

fun set_up_agent(scenario: &mut Scenario) {
    call_init_agents(scenario);
    scenario.next_tx(Admin);
    call_add_valid_agent_types(scenario);
    scenario.next_tx(Admin);
    call_create_agent(scenario);
    scenario.next_tx(Admin);
}

fun create_usdc_and_ngnc_pools(scenario: &mut Scenario): (Pool<USDC>,Pool<NGNC>){
    call_init_pool(scenario);
    scenario.next_tx(Admin);
    call_create_pool<NGNC>(scenario);
    scenario.next_tx(Admin);
    let ngnc_pool = scenario.take_shared<Pool<NGNC>>();
    scenario.next_tx(Admin);
    call_create_pool<USDC>(scenario);
    scenario.next_tx(Admin);
    let usdc_pool = scenario.take_shared<Pool<USDC>>();
    (usdc_pool, ngnc_pool)
}

fun create_pool<T>(scenario: &mut Scenario): Pool<T> {
    call_init_pool(scenario);
    scenario.next_tx(Admin);
    call_create_pool<T>(scenario);
    scenario.next_tx(Admin);
    scenario.take_shared<Pool<T>>()
}

fun mint_ngnc_to_pool(scenario: &mut Scenario, pool: &mut Pool<NGNC>, sender: address, usdc_coin: Coin<USDC>){
    call_init_ngnc(scenario);
    scenario.next_tx(sender);
    call_create_reserve_ngnc(scenario);
    scenario.next_tx(sender);
    call_mint_ngnc(scenario, pool, usdc_coin);
}

fun mint_ngnc_return_coin(scenario: &mut Scenario, pool_a: &mut Pool<USDC>,pool_b: &mut Pool<NGNC>, sender: address, usdc_coin: Coin<USDC>, coin_a: Coin<USDC>): Coin<NGNC>{
    mint_ngnc_to_pool(scenario, pool_b, sender, usdc_coin);
    scenario.next_tx(Admin);
    call_swap_a_2_b<USDC, NGNC>(pool_a, pool_b, scenario, coin_a);
    scenario.next_tx(sender);
    call_get_ngnc(scenario)
}

fun mint_usdc_return_coin(scenario: &mut Scenario, sender: address, amount: u64) : Coin<USDC>{
    call_init_usdc(scenario);
    scenario.next_tx(sender);
    call_mint_usdc(scenario, amount);
    scenario.next_tx(sender);
    call_get_usdc(scenario)
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
    let usdc_coin = mint_usdc_return_coin(&mut scenario, Admin, 1000000000);
    scenario.next_tx(Admin);
    let mut ngnc_pool = create_pool<NGNC>(&mut scenario);
    scenario.next_tx(Admin);
    mint_ngnc_to_pool(&mut scenario, &mut ngnc_pool, Admin, usdc_coin);
    ts::return_shared(ngnc_pool);
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
    set_up_agent(&mut scenario);
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

#[test]
fun test_convert_usdc_to_ngnc() {
    let mut scenario = ts::begin(Admin);
    let mut usdc_coin = mint_usdc_return_coin(&mut scenario, Admin, 1000000000);
    let usdc_coin2 =  coin::split(&mut usdc_coin, 100000000, scenario.ctx());
    scenario.next_tx(Admin);
    let (mut usdc_pool,mut ngnc_pool) = create_usdc_and_ngnc_pools(&mut scenario);
    call_init_ngnc(&mut scenario);
    scenario.next_tx(Admin);
    call_create_reserve_ngnc(&mut scenario);
    scenario.next_tx(Admin);
    call_mint_ngnc(&mut scenario, &mut ngnc_pool, usdc_coin);
    scenario.next_tx(Admin);
    call_swap_a_2_b<USDC, NGNC>(&mut usdc_pool, &mut ngnc_pool,&mut scenario, usdc_coin2);
    ts::return_shared(usdc_pool);
    ts::return_shared(ngnc_pool);
    scenario.end();
}

#[test]
fun test_add_agent_balance_admin() {
    let mut scenario = ts::begin(Admin);
    let mut usdc_coin = mint_usdc_return_coin(&mut scenario, Admin, 1000000000);
    let usdc_coin2 =  coin::split(&mut usdc_coin, 100000000, scenario.ctx());
    scenario.next_tx(Admin);
    let (mut usdc_pool,mut ngnc_pool) = create_usdc_and_ngnc_pools(&mut scenario);
    scenario.next_tx(Admin);
    let ngnc_coin = mint_ngnc_return_coin(&mut scenario, &mut usdc_pool, &mut ngnc_pool, Admin, usdc_coin, usdc_coin2);
    scenario.next_tx(Admin);
    set_up_agent(&mut scenario);
    let agent = call_get_agent(&scenario);
    scenario.next_tx(Admin);
    call_add_agent_balance_admin(&mut scenario, agent, ngnc_coin);
    ts::return_shared(usdc_pool);
    ts::return_shared(ngnc_pool);
    scenario.end();
}