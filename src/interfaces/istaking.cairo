#[starknet::interface]
pub trait ISimpleStaking<TState> {
    fn add_rewards(ref self: TState, amount: u128);
}