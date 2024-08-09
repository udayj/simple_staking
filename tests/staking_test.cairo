#[starknet::contract]
pub mod ConsumerMock {

    use simple_staking::simple_staking::SimpleStakingComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SimpleStakingComponent, storage: simple_staking, event: SimpleStakingEvent );

    #[abi(embed_v0)]
    impl SimpleStakingImpl = SimpleStakingComponent::SimpleStakingImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl SimpleStakingInternalImpl = SimpleStakingComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {

        #[substorage(v0)]
        simple_staking: SimpleStakingComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SimpleStakingEvent: SimpleStakingComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, reward_token: ContractAddress, stake_token: ContractAddress) {
        self.ownable.initializer(owner);
        self.simple_staking.initializer(reward_token, stake_token);
    }
}