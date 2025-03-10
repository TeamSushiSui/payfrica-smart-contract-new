#[test_only]
module payfrica::payfrica_tests{
    // uncomment this line to import the module
    // use payfrica::payfrica;
    use payfrica::ngnc;
    use payfrica::pool;
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::debug::print;

    const ENotImplemented: u64 = 0;

    public struct USDC has drop{}

    #[test]
    fun test_payfrica_pool_create_pool() {
        let creator = @0xA;

        let mut scenario = ts::begin(creator);
        {
            pool::new_pool<ngnc::NGNC, USDC>(scenario.ctx());
        };
        scenario.end();
    }

    #[test]
    fun test_payfrica_pool_add_liquidity_a() {
        let creator = @0xA;
        let lq_provider = @0xB;

        let mut scenario = ts::begin(creator);
        {
            ngnc::call_init(scenario.ctx());
            let id = scenario.most_recent_id_for_sender<TreasuryCap<ngnc::NGNC>>();
            let mut treasury_cap = scenario.take_from_sender<TreasuryCap<ngnc::NGNC>>();
            // ngnc::mint(&mut treasury_cap, 1000000000, lq_provider, scenario.ctx());
            // pool::new_pool<ngnc::NGNC, USDC>(scenario.ctx());
            ts::return_to_sender(&scenario, treasury_cap);
        };

        // scenario.next_tx(lq_provider);
        // {
        //     let mut pool_id = ts::most_recent_id_shared<pool::Pool<ngnc::NGNC, USDC>>();
        //     let mut created_pool : pool::Pool<ngnc::NGNC, USDC> = scenario.take_shared_by_id(pool_id.extract());
        //     let ngnc = scenario.take_from_sender<Coin<ngnc::NGNC>>();
        //     pool::add_liquidity_a(&mut created_pool, ngnc, scenario.ctx());
        //     ts::return_shared(created_pool);
        // };
        scenario.end();
    }

    #[test, expected_failure(abort_code = ::payfrica::payfrica_tests::ENotImplemented)]
    fun test_payfrica_fail() {
        abort ENotImplemented
    }
}