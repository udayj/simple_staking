#[starknet::component]
pub mod SimpleStakingComponent {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::access::ownable::OwnableComponent;
    use simple_staking::interfaces::istaking::ISimpleStaking;
    use openzeppelin::access::ownable::interface::IOwnable;
    use cubit::f128::types::fixed::{Fixed, FixedTrait};
    use core::traits::TryInto;

    // custom type for storing user shares, withdrawn status - done
    // support for decimals - convert numerator and denominator into Fixed128 and divide and convert back to u128
    // tests
    // mod Errors
    // comments

    #[derive(Drop, starknet::Store)]
    pub struct ShareStatus {
        shares: u128,
        withdrawn_rewards: u128
    }

    #[storage]
    struct Storage {
        real_total_rewards: u128,
        total_rewards: u128,
        withdrawn_rewards: u128,
        real_withdrawn_rewards: u128,
        user_status: LegacyMap<ContractAddress, ShareStatus>,
        total_shares: u128,
    }

    #[embeddable_as(SimpleStakingImpl)]
    impl SimpleStaking<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>
    > of ISimpleStaking<ComponentState<TContractState>> {
        fn add_share(ref self: ComponentState<TContractState>, user_share: u128) {
            let reward_increase:u128 = self.inflation(user_share);
            self.total_rewards.write(self.total_rewards.read() + reward_increase);
            self.withdrawn_rewards.write(self.withdrawn_rewards.read() + reward_increase);
            self.total_shares.write(self.total_shares.read() + user_share);
            let user = get_caller_address();
            let user_status:ShareStatus = self.user_status.read(user);
            let updated_shares:u128 = user_status.shares  + user_share;
            let updated_user_status = ShareStatus {
                shares: updated_shares,
                withdrawn_rewards: user_status.withdrawn_rewards + reward_increase
            };
            self.user_status.write(user, updated_user_status);
        }

        fn add_rewards(ref self: ComponentState<TContractState>, amount: u128) {
            let ownable_component = get_dep_component!(@self, Ownable);
            let caller = get_caller_address();
            assert(caller == ownable_component.owner(), 'UNAUTHORIZED');
            self.real_total_rewards.write(self.real_total_rewards.read() + amount);
            self.total_rewards.write(self.total_rewards.read() + amount);
        }

        fn claim_rewards(ref self: ComponentState<TContractState>) -> u128 {
            let user = get_caller_address();
            let user_status = self.user_status.read(user);
            let inflation = self.inflation(user_status.shares);
            let rewards_remaining = self.total_rewards.read() - self.withdrawn_rewards.read();
            let rewards_withdrawn_by_user = user_status.withdrawn_rewards;
            let user_portion = if rewards_withdrawn_by_user > inflation {
                0
            } else {
                inflation - rewards_withdrawn_by_user
            };

            let withdrawable_amount = self.min(user_portion, rewards_remaining);
            let updated_user_status = ShareStatus {
                shares: user_status.shares,
                withdrawn_rewards: user_status.withdrawn_rewards + withdrawable_amount
            };
            self.user_status.write(user, updated_user_status);
            self.withdrawn_rewards.write(self.withdrawn_rewards.read() + withdrawable_amount);
            self
                .real_withdrawn_rewards
                .write(self.real_withdrawn_rewards.read() + withdrawable_amount);
            withdrawable_amount
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn inflation(self: @ComponentState<TContractState>, user_share: u128) -> u128 {
            let increase = if self.total_shares.read() == 0 {
                0
            } else {
                let total_rewards_f128 = FixedTrait::new(self.total_rewards.read(), false);
                let total_shares_f128 = FixedTrait::new(self.total_shares.read(), false);
                let user_share_f128 = FixedTrait::new_unscaled(user_share, false);
                let reward_per_share_f128 = total_rewards_f128 / total_shares_f128;
                let total_user_reward_f128 = reward_per_share_f128 * user_share_f128;

                // guaranteed to unwrap since sign is false
                let total_user_reward:u128 = total_user_reward_f128.try_into().unwrap(); 
                total_user_reward
            };

            increase
        }

        fn min(self: @ComponentState<TContractState>, a: u128, b: u128) -> u128 {
            if a <= b {
                a
            } else {
                b
            }
        }
    }
}
