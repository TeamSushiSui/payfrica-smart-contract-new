// module payfrica::saving_circle;

// use sui::{
//     balance::{Self, Balance},
//     coin::{Self, Coin,},
//     table::{Self,Table},
//     dynamic_field as df,
//     event
// };

// use std::type_name::{Self, TypeName};
// use payfrica::pool::{Self, Pool};

// public struct SavingCircle has key{
//     id: UID,
//     members: vector<address>,
//     pending_members: vector<address>,
//     payout_turn: u8,
//     creator: address,
//     coin_type: TypeName,
//     contribution_amount: Option<u64>,
//     cycle_duration: u64,
//     current_round: u64,
//     active: bool,    
//     max_members: Option<u16>,
//     start_date: u64,
//     end_date: Option<u64>,
// }

// public struct Member has store{
//     payment_history: Table<u64, bool>,
//     total_contributions: u64,
//     is_paid: bool,
//     payout_round: u64,
// }

// public fun create_saving_cicke<T0,T1>(ctx: &mut TxContext){
//     let saving_circle = SavingCircle{
//         id: object::new(ctx),
//         members: vector::empty<address>(),
//         pending_members: vector::empty<address>(),
//         payout_turn: 0,
//         creator: ctx.sender(),
//         coin_type: type_name::get<T0>(),
//         contribution_amount: option::none(),
//         cycle_duration: 0,
//         current_round: 0,
//         active: false,
//         max_members: option::none(),
//         start_date: 0,
//         end_date: option::none(),
//     };
//     transfer::share_object(saving_circle);
// }

// public fun join_saving_circle(saving_circle: &mut SavingCircle, ctx: &mut TxContext){
//     let sender = ctx.sender();
//     assert!(!saving_circle.members.contains(sender), 0);                            
//     saving_circle.pending_members.push(sender);
// }