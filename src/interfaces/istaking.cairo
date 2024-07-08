#[starknet::interface]
pub trait ISimpleStaking<TState> {
    fn add_share(ref self: TState, user_share: u256);
    fn add_rewards(ref self: TState, amount: u256);
    fn claim_rewards(ref self: TState) ->  u256;
    //fn remove_shares(ref self: TState);
}