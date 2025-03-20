#[test_only]
module payfrica::payfrica_tests{
    // uncomment this line to import the module
    // use payfrica::payfrica;
    use payfrica::{
        ngnc::{Self, NGNC},
        usdc::{Self, USDC},
        pool::{Self, Pool, PayfricaPool}
    };
    use sui::{
        test_scenario::{Self as ts, Scenario},
        coin::{Self, Coin, TreasuryCap},
        test_utils::assert_eq,
    };
    use std::debug;

    const ENotImplemented: u64 = 0;
    const CREATOR : address =  @0xa;
    const USER: address = @0xb;
    const USER1: address = @0xc;
    const USER2: address = @0xd;

    fun call_init(scenario: &mut Scenario) {
        pool::call_init(scenario.ctx());
    }

    fun call_create_pool(scenario: &mut Scenario){
        pool::new_pool<NGNC, USDC>(scenario.ctx());
    }
    fun call_ngnc_mint(scenario: &mut Scenario, lq_provider: address,amount: u64){
        // let id = scenario.most_recent_id_for_sender<TreasuryCap<NGNC>>();
        let mut treasury_cap = scenario.take_from_sender<TreasuryCap<NGNC>>();
        ngnc::mint(&mut treasury_cap, amount, lq_provider, scenario.ctx());
        ts::return_to_sender(scenario, treasury_cap);
    }

    fun call_usdc_mint(scenario: &mut Scenario, lq_provider: address,amount: u64){
        // let id = scenario.most_recent_id_for_sender<TreasuryCap<USDC>>();
        let mut treasury_cap = scenario.take_from_sender<TreasuryCap<USDC>>();
        usdc::mint(&mut treasury_cap, amount, lq_provider, scenario.ctx());
        ts::return_to_sender(scenario, treasury_cap);
    }
    fun call_add_liquidity_a(scenario: &mut Scenario){
        let mut pool = scenario.take_shared<Pool<NGNC, USDC>>();
        let mut payfrica_pool  = scenario.take_shared<PayfricaPool>();
        let ngnc = scenario.take_from_sender<Coin<NGNC>>();
        pool.add_liquidity_a(&mut payfrica_pool, ngnc, scenario.ctx());
        ts::return_shared(payfrica_pool);
        ts::return_shared(pool);
    }
    fun call_add_liquidity_b(scenario: &mut Scenario){
        let mut pool = scenario.take_shared<Pool<NGNC, USDC>>();
        let mut payfrica_pool  = scenario.take_shared<PayfricaPool>();
        let ngnc = scenario.take_from_sender<Coin<USDC>>();
        pool.add_liquidity_b(&mut payfrica_pool, ngnc, scenario.ctx());
        ts::return_shared(payfrica_pool);
        ts::return_shared(pool);
    }

    fun call_remove_liquidity_a(amount: u64, scenario: &mut Scenario){
        let mut pool = scenario.take_shared<Pool<NGNC, USDC>>();
        pool.remove_liquidity_a(amount, scenario.ctx());
        ts::return_shared(pool);
    }

    fun check_tokens_a(scenario: &mut Scenario, amount: u64){
        let ngnc = scenario.take_from_sender<Coin<NGNC>>();
        assert_eq(ngnc.value(), amount);
        scenario.return_to_sender(ngnc);
    }

    fun check_tokens_b(scenario: &mut Scenario, amount: u64){
        let usdc = scenario.take_from_sender<Coin<USDC>>();
        assert_eq(usdc.value(), amount);
        scenario.return_to_sender(usdc);
    }

    #[test]
    fun test_call_init() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_payfrica_pool_create_pool() {
        let mut scenario = ts::begin(CREATOR);
        call_create_pool(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_add_liquity_a() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.next_tx(CREATOR);
        call_create_pool(&mut scenario);
        scenario.next_tx(USER);
        ngnc::call_init(scenario.ctx());
        scenario.next_tx(USER);
        call_ngnc_mint(&mut scenario, USER, 1000000000);
        scenario.next_tx(USER);
        call_add_liquidity_a(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_add_liquity_b() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.next_tx(CREATOR);
        call_create_pool(&mut scenario);
        scenario.next_tx(USER);
        usdc::call_init(scenario.ctx());
        scenario.next_tx(USER);
        call_usdc_mint(&mut scenario, USER, 100000000);
        scenario.next_tx(USER);
        call_add_liquidity_b(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_add_liquity_a_b() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.next_tx(CREATOR);
        call_create_pool(&mut scenario);
        scenario.next_tx(USER);
        ngnc::call_init(scenario.ctx());
        scenario.next_tx(USER);
        call_ngnc_mint(&mut scenario, USER, 100000000);
        scenario.next_tx(USER);
        call_add_liquidity_a(&mut scenario);
        scenario.next_tx(USER1);
        usdc::call_init(scenario.ctx());
        scenario.next_tx(USER1);
        call_usdc_mint(&mut scenario, USER1, 100000000);
        scenario.next_tx(USER1);
        call_add_liquidity_b(&mut scenario);
        scenario.end();
    }

    #[test]
    fun test_remove_liquity_a_all() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.next_tx(CREATOR);
        call_create_pool(&mut scenario);
        scenario.next_tx(USER);
        ngnc::call_init(scenario.ctx());
        scenario.next_tx(USER);
        call_ngnc_mint(&mut scenario, USER, 1000000000);
        scenario.next_tx(USER);
        call_add_liquidity_a(&mut scenario);
        scenario.next_tx(USER);
        call_remove_liquidity_a(1000000000, &mut scenario);
        scenario.next_tx(USER);
        check_tokens_a(&mut scenario, 1000000000);
        scenario.end();
    }

    #[test]
    fun test_remove_liquity_a_part() {
        let mut scenario = ts::begin(CREATOR);
        call_init(&mut scenario);
        scenario.next_tx(CREATOR);
        call_create_pool(&mut scenario);
        scenario.next_tx(USER);
        ngnc::call_init(scenario.ctx());
        scenario.next_tx(USER);
        call_ngnc_mint(&mut scenario, USER, 1000000000);
        scenario.next_tx(USER);
        call_add_liquidity_a(&mut scenario);
        scenario.next_tx(USER);
        call_remove_liquidity_a(100000, &mut scenario);
        scenario.next_tx(USER);
        check_tokens_a(&mut scenario, 100000);
        scenario.end();
    }

    // #[test]
    // fun test_payfrica_pool_add_liquidity_a() {
    //     let creator = @0xA;
    //     let lq_provider = @0xB;

    //     let mut scenario = ts::begin(creator);
    //     {
    //         ngnc::call_init(scenario.ctx());
    //         let id = scenario.most_recent_id_for_sender<TreasuryCap<ngnc::NGNC>>();
    //         let mut treasury_cap = scenario.take_from_sender<TreasuryCap<ngnc::NGNC>>();
    //         // ngnc::mint(&mut treasury_cap, 1000000000, lq_provider, scenario.ctx());
    //         // pool::new_pool<ngnc::NGNC, USDC>(scenario.ctx());
    //         ts::return_to_sender(&scenario, treasury_cap);
    //     };

    //     // scenario.next_tx(lq_provider);
    //     // {
    //     //     let mut pool_id = ts::most_recent_id_shared<pool::Pool<ngnc::NGNC, USDC>>();
    //     //     let mut created_pool : pool::Pool<ngnc::NGNC, USDC> = scenario.take_shared_by_id(pool_id.extract());
    //     //     let ngnc = scenario.take_from_sender<Coin<ngnc::NGNC>>();
    //     //     pool::add_liquidity_a(&mut created_pool, ngnc, scenario.ctx());
    //     //     ts::return_shared(created_pool);
    //     // };
    //     scenario.end();
    // }

    #[test, expected_failure(abort_code = ::payfrica::payfrica_tests::ENotImplemented)]
    fun test_payfrica_fail() {
        abort ENotImplemented
    }
}