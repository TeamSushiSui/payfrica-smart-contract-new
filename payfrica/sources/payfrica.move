// Module: payfrica
module payfrica::payfrica;

use sui::package::{Self, Publisher};
use sui::pay;

const ENotAnAdmin: u64 = 0;
const ENotAuthorized: u64 = 1;

public struct Payfrica has key{
    id: UID,
    admin: vector<address>,
    users: vector<address>,
}

public struct PAYFRICA has drop {}

public struct PayfricaUser has key, store{
    id: UID,
    addr: address,
}

fun init(otw: PAYFRICA,ctx: &mut TxContext){
    let publisher : Publisher = package::claim(otw, ctx);
    let payfrica = Payfrica{
        id: object::new(ctx),
        admin: vector::empty<address>(),
        users: vector::empty<address>(),
    };
    transfer::public_transfer(publisher, ctx.sender());
    transfer::share_object(payfrica);
}

public fun make_user(payfrica: &mut Payfrica, user_address: address,ctx: &mut TxContext){
    assert!(payfrica.admin.contains(&ctx.sender()), ENotAnAdmin);
    assert!(payfrica.users.contains(&user_address), ENotAuthorized);
    let user = PayfricaUser{
        id: object::new(ctx),
        addr: user_address
    };
    payfrica.users.push_back(user_address);
    transfer::public_transfer(user, user_address);
}

public fun add_admin(cap : &Publisher, payfrica: &mut Payfrica, admin: address){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    payfrica.admin.push_back(admin);
}

public fun remove_admin(cap : &Publisher, payfrica: &mut Payfrica, admin: address){
    assert!(cap.from_module<Payfrica>(), ENotAuthorized);
    let mut i = 0;
    while(i < payfrica.admin.length()){
        if (payfrica.admin.borrow(i) == admin){
            payfrica.admin.remove(i);
        };
        i = i + 1;
    };
}

public fun check_payfrica_user(payfrica: &Payfrica, payfrica_user: &PayfricaUser) : bool{
    payfrica.users.contains(&payfrica_user.addr)
}

// public struct PayfricaDB has key{
//     id: UID,
    
// }

// public struct User has store{
//     addr: address,
// }

// ngnc --> 0xc981a7aa31f6237e1fb04d60705abf84325ccfad2e78ac42421b4f76c92d9e67 0x2::coin::CoinMetadata<0x9e32e11ca091cb21b2fb882e96bb4ec42382c4e72f4cf3c370331ea0c98b45c9::ngnc::NGNC> 0xc981a7aa31f6237e1fb04d60705abf84325ccfad2e78ac42421b4f76c92d9e67
// ghsc --> 0x2bd514a7aecbfdbb80f025a6d30e5cbf25d9dcdacdaa6425498deea5d9cb6ad8 0x2::coin::CoinMetadata<0x9e32e11ca091cb21b2fb882e96bb4ec42382c4e72f4cf3c370331ea0c98b45c9::ghsc::GHSC> 0x97da80b823153fe323e4b80f63767ed4b3306d86395c807c3325cda9ceb11163
// payfricaPool --> 0x80b868e4b1fbccf7ceec90ee58b354de427ce1fef4a64e675076faded60f4b03 0x9e32e11ca091cb21b2fb882e96bb4ec42382c4e72f4cf3c370331ea0c98b45c9::pool::PayfricaPool
// usdc --> 0x67507eea83c2bc09a963ce8326d14a176e2ffc723c117df8f238211571a79014 0x2::coin::CoinMetadata<0x9e32e11ca091cb21b2fb882e96bb4ec42382c4e72f4cf3c370331ea0c98b45c9::usdc::USDC> 0xfec0aba7c61949cb3a1ed99ce8c82b020d0dd2952b6d07feff3c34d5aa3b7c09


// package --> 0x9e32e11ca091cb21b2fb882e96bb4ec42382c4e72f4cf3c370331ea0c98b45c9
// publisher --> 0xa6fb0b88ced24705d04941cba7adecb1e985331a88d7c4da01436abe299b9e27

//ngnc/usdc pool --> 0x8e8d499045006ea11838f49e5055a93c07b64fc7b5e0c3ad664263d2b00ce5de