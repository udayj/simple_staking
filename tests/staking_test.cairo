use core::array::ArrayTrait;
use starknet::{ContractAddress, contract_address_const, 
        testing::{set_contract_address, pop_log_raw},
};
use starknet::syscalls::{deploy_syscall, call_contract_syscall};

use super::consumer_mock::ConsumerMock;
use super::erc20::ERC20;
use simple_staking::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use simple_staking::interfaces::istaking::{ISimpleStakingDispatcher, ISimpleStakingDispatcherTrait};
use starknet::testing::{set_caller_address};

fn deploy(
        contract_class_hash: felt252, salt: felt252, calldata: Array<felt252>
    ) -> ContractAddress {
        let (address, _) = deploy_syscall(
            contract_class_hash.try_into().unwrap(), salt, calldata.span(), false
        )
            .unwrap();
        address
}

fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {

    let owner: ContractAddress = contract_address_const::<100>();
    let name:ByteArray = "STAKE";
    let symbol:ByteArray = "STAKE";
    let decimals: u8 = 18;
    let amount: u256 = 10000;
    let mut calldata = ArrayTrait::<felt252>::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    decimals.serialize(ref calldata);
    owner.serialize(ref calldata);
    amount.serialize(ref calldata);
    let stake_token = deploy(ERC20::TEST_CLASS_HASH, 1, calldata);


    let name:ByteArray = "REWARD";
    let symbol:ByteArray = "REWARD";
    let decimals: u8 = 18;
    let amount: u256 = 10000;
    let mut calldata = ArrayTrait::<felt252>::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    decimals.serialize(ref calldata);
    owner.serialize(ref calldata);
    amount.serialize(ref calldata);

    let reward_token = deploy(ERC20::TEST_CLASS_HASH, 2, calldata);

    let mut calldata = ArrayTrait::<felt252>::new();
    owner.serialize(ref calldata);
    reward_token.serialize(ref calldata);
    stake_token.serialize(ref calldata);
    let consumer_mock = deploy(ConsumerMock::TEST_CLASS_HASH, 3, calldata);

    return (stake_token, reward_token, consumer_mock);
    // Stake, Claim Rewards
}

#[test]
fn test_basic_flow() {

    let (stake_token_address, reward_token_address, consumer_mock_address) = setup();
    
    let user1 = contract_address_const::<1>();
    let user2 = contract_address_const::<2>();
    let owner = contract_address_const::<100>();
    let stake_token = IERC20Dispatcher {contract_address: stake_token_address};
    let reward_token = IERC20Dispatcher {contract_address: reward_token_address};
    let consumer_mock = ISimpleStakingDispatcher { contract_address: consumer_mock_address};
    assert_eq!(stake_token.balance_of(owner), 10000);
    set_contract_address(owner);
    stake_token.transfer(user1, 100);
    set_contract_address(user1);
    stake_token.approve(consumer_mock_address, 100);
    
    consumer_mock.add_share(100);

    // Rewards should be 0 since no rewards are available
    let rewards = consumer_mock.get_claimable_rewards(user1);
    assert_eq!(rewards,0);
    set_contract_address(owner);
    reward_token.approve(consumer_mock_address, 100);

    consumer_mock.add_rewards(100);
    
    // All the rewards belong to user1
    let rewards = consumer_mock.get_claimable_rewards(user1);
    assert_eq!(rewards,100);

    set_contract_address(owner);
    stake_token.transfer(user2, 100);
    set_contract_address(user2);
    stake_token.approve(consumer_mock_address, 100);
    consumer_mock.add_share(100);
    // user2 should not get any rewards yet because all previous rewards belong to user1
    let rewards = consumer_mock.get_claimable_rewards(user2);
    assert_eq!(rewards,0);

    // More rewards get added which will now be split according to relative share in the staking pool
    set_contract_address(owner);
    reward_token.approve(consumer_mock_address, 100);
    consumer_mock.add_rewards(100);

    // user2 now gets 50% of the *new* rewards according to share
    let rewards = consumer_mock.get_claimable_rewards(user2);
    assert_eq!(rewards,50);

    // user1 gets 50% of new rewards because user2 has equal stake, and 100% of previous rewards
    let rewards = consumer_mock.get_claimable_rewards(user1);
    assert_eq!(rewards,150);
}
