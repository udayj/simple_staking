#[starknet::component]
pub mod SimpleStakingComponent {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use simple_staking::interfaces::istaking::ISimpleStaking;
    use openzeppelin::access::ownable::interface::IOwnable;
    use cubit::f128::types::fixed::{Fixed, FixedTrait};
    use core::traits::TryInto;
    use simple_staking::interfaces::ierc20::{IERC20DispatcherTrait, IERC20Dispatcher};

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
        reward_token: ContractAddress,
        stake_token: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AddShare: AddShare,
        ClaimRewards: ClaimRewards
    }

    #[derive(Drop, starknet::Event)]
    struct AddShare {

        #[key]
        user: ContractAddress,
        share: u128
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimRewards {

        #[key]
        user: ContractAddress,
        reward: u128
    }

    // check for correct share token should be done at contract using the component

    #[embeddable_as(SimpleStakingImpl)]
    impl SimpleStaking<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>
    > of ISimpleStaking<ComponentState<TContractState>> {
    

        fn add_share(ref self: ComponentState<TContractState>, user_share: u128) {

            let user = get_caller_address();
            let stake_token = IERC20Dispatcher{ contract_address: self.stake_token.read()};
            stake_token.transfer_from(user, get_contract_address(), user_share.into());
            // We are explicitly limiting the amount staked and rewarded to u128 for simplicity
            let reward_increase:u128 = self.inflation(user_share);
            self.total_rewards.write(self.total_rewards.read() + reward_increase);
            self.withdrawn_rewards.write(self.withdrawn_rewards.read() + reward_increase);
            self.total_shares.write(self.total_shares.read() + user_share);
           
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
            let reward_token = IERC20Dispatcher{ contract_address: self.reward_token.read()};
            reward_token.transfer_from(caller, get_contract_address(), amount.into());
            self.real_total_rewards.write(self.real_total_rewards.read() + amount);
            self.total_rewards.write(self.total_rewards.read() + amount);
        }

        // @notice - Claim function to be called by user to claim accumulated rewards
        // This function transfers the reward tokens to the user and returns the number of tokens transferred
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
            let reward_token = IERC20Dispatcher{contract_address: self.reward_token.read()};

            // TODO: Check we have enough tokens to send to user
            reward_token.transfer(user, withdrawable_amount.into());
            withdrawable_amount
        }

        fn get_claimable_rewards(self: @ComponentState<TContractState>, user:ContractAddress) ->  u128 {

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
            withdrawable_amount

        }
        // TODO - Withdraw rewards
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {

        fn initializer(ref self: ComponentState<TContractState>, reward_token: ContractAddress, stake_token: ContractAddress) {

            self.reward_token.write(reward_token);
            self.stake_token.write(stake_token);
        }

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
