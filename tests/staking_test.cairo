#[starknet::contract]
pub mod ConsumerMock {

    use simple_staking::simple_staking::SimpleStakingComponent;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable_storage, event: OwnableEvent);
    component!(path: SimpleStakingComponent, storage: simple_staking_storage, event: SimpleStakingEvent );

    #[abi(embed_v0)]
    impl SimpleStakingImpl = SimpleStakingComponent::SimpleStakingImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {

        #[substorage(v0)]
        simple_staking_storage: SimpleStakingComponent::Storage,
        #[substorage(v0)]
        ownable_storage: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SimpleStakingEvent: SimpleStakingComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }


}