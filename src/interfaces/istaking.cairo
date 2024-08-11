use starknet::ContractAddress;
#[starknet::interface]
pub trait ISimpleStaking<TState> {
    fn add_rewards(ref self: TState, amount: u128);
    fn claim_rewards(ref self: TState) -> u128;
    fn add_share(ref self: TState, user_share: u128);
    fn get_claimable_rewards(self:@TState, user:ContractAddress) -> u128;
}