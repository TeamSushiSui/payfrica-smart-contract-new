module payfrica::naming;
use sui::table::{Self, Table};
use std::string::String;

const NameAlreadyExists: u64 = 0;
const NameDoesNotExists: u64 = 1;
const NotNameOwner: u64 = 2;

public struct Names has key{
    id: UID,
    namings: Table<String,address>,
}

public struct NAMING has drop {}

fun init(otw: NAMING, ctx: &mut TxContext) {
    let names = Names{
        id: object::new(ctx),
        namings: table::new<String, address>(ctx),
    };
    transfer::share_object(names);
}

public fun register_name(names: &mut Names, name: String, ctx: &mut TxContext){
    assert!(!names.namings.contains(name), NameAlreadyExists);
    names.namings.add(name, ctx.sender());
}

public fun get_address(names: &Names, name: String): address{
    assert!(names.namings.contains(name), NameDoesNotExists);
    *names.namings.borrow(name)
}

public fun change_name(names: &mut Names, old_name: String, new_name: String, ctx: &mut TxContext){
    assert!(names.namings.contains(old_name), NameDoesNotExists);
    assert!(!names.namings.contains(new_name), NameAlreadyExists);
    assert!(names.namings.borrow(old_name) == ctx.sender(), NotNameOwner);
    names.namings.remove(old_name);
    names.namings.add(new_name, ctx.sender());
}

public fun check_name_exists(names: &Names, name: String): bool{
    names.namings.contains(name)
}