
// Inspired by inflation/dilution resistant staking design at Acala Network

#[starknet::component]
pub mod SimpleStakingComponent {

    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::ownable::OwnableComponent;
    use simple_staking::interfaces::istaking::ISimpleStaking;
    use openzeppelin::access::ownable::interface::IOwnable;

    #[storage]
    struct Storage {
        real_total_rewards: u256,
        total_rewards: u256,
        withdrawn_rewards: u256,
        real_withdrawn_rewards: u256,
        user_shares: LegacyMap<ContractAddress, u256>,
        user_withdrawn_rewards: LegacyMap<ContractAddress, u256>,
        total_shares: u256
    }

    #[embeddable_as(SimpleStakingImpl)]
    impl SimpleStaking<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>
    > of ISimpleStaking<ComponentState<TContractState>> {

        fn add_share(ref self: ComponentState<TContractState>, user_share: u256) {
            let reward_increase = self.inflation(user_share);
            self.total_rewards.write(self.total_rewards.read() + reward_increase);
            self.withdrawn_rewards.write(self.withdrawn_rewards.read() + reward_increase);
            self.total_shares.write(self.total_shares.read() + user_share);
            let user = get_caller_address();
            self.user_shares.write(user, self.user_shares.read(user) + user_share);
            let rewards_withdrawn_by_user = self.user_withdrawn_rewards.read(user);
            self.user_withdrawn_rewards.write(user, rewards_withdrawn_by_user + reward_increase);

        }

        fn add_rewards(ref self: ComponentState<TContractState>, amount: u256) {

            let ownable_component = get_dep_component!(@self, Ownable);
            let caller = get_caller_address();
            assert(caller == ownable_component.owner(),'UNAUTHORIZED');
            self.real_total_rewards.write(self.real_total_rewards.read() + amount);
            self.total_rewards.write(self.total_rewards.read() + amount);
        }

        fn claim_rewards(ref self: ComponentState<TContractState>) -> u256 {

            let user = get_caller_address();
            let user_share = self.user_shares.read(user);
            let inflation = self.inflation(user_share);
            let rewards_remaining = self.total_rewards.read() - self.withdrawn_rewards.read();
            let rewards_withdrawn_by_user = self.user_withdrawn_rewards.read(user);
            let user_portion = if rewards_withdrawn_by_user > inflation {
                0
            }
            else {
                inflation - rewards_withdrawn_by_user
            };

            let withdrawable_amount = self.min(user_portion, rewards_remaining);
            self.user_withdrawn_rewards.write(user, rewards_withdrawn_by_user + withdrawable_amount);
            self.withdrawn_rewards.write(self.withdrawn_rewards.read() + withdrawable_amount);
            self.real_withdrawn_rewards.write(self.real_withdrawn_rewards.read() + withdrawable_amount);
            withdrawable_amount
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>
    > of InternalTrait<TContractState> {

        fn inflation(self: @ComponentState<TContractState>, user_share: u256) -> u256 {
            let increase = if self.total_shares.read() == 0 {
                0
            }
            else {
                (self.total_rewards.read()/self.total_shares.read()) * user_share
            };

            increase
        }

        fn min(self: @ComponentState<TContractState>, a: u256, b: u256) -> u256 {

            if a<=b {
                a
            }
            else {
                b
            }
        }
    }

}