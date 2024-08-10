use core::array::ArrayTrait;
use starknet::{ContractAddress, contract_address_const, 
        testing::{set_contract_address, pop_log_raw},
};
use starknet::syscalls::{deploy_syscall, call_contract_syscall};

use super::consumer_mock::ConsumerMock;

fn deploy(
        contract_class_hash: felt252, salt: felt252, calldata: Array<felt252>
    ) -> ContractAddress {
        let (address, _) = deploy_syscall(
            contract_class_hash.try_into().unwrap(), salt, calldata.span(), false
        )
            .unwrap();
        address
}

fn setup() {

    let owner: ContractAddress = contract_address_const::<1>();
    // Deploy ERC20
    // Deploy ConsumerMock
    // Stake, Claim Rewards
}
