use starknet::ContractAddress;

#[starknet::contract]
pub mod ERC20 {
    use super::{ContractAddress};

    use simple_staking::interfaces::ierc20::IERC20;
    use starknet::get_caller_address;
    use core::num::traits::Zero;
    
    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balance: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        name: ByteArray, 
        symbol: ByteArray, 
        decimals: u8, 
        initiator:ContractAddress,
        amount: u256
    ) {

        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self._mint(initiator, amount);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let spender = get_caller_address();
            let allowance = self.allowances.read((sender, spender));
            assert(allowance >= amount, 'ERC20: Insufficient allowance');
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self._approve(owner, spender, amount);
            true
        }
    }

    #[generate_trait]
    impl PrivateERC20Impl of ERC20PrivateTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(self.balance_of(sender) >= amount, 'ERC20: Insufficient Balance');
            self.balance.write(sender, self.balance.read(sender) - amount);
            self.balance.write(recipient, self.balance.read(recipient) + amount);
        }

        fn _decrease_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let owner = get_caller_address();
            self._approve(owner, spender, self.allowances.read((owner, spender)) - amount);
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance: u256 = self.allowances.read((owner, spender));
            let is_unlimited_allowance = (current_allowance == core::integer::BoundedInt::max());
            if !is_unlimited_allowance {
                self._approve(owner, spender, current_allowance - amount);
            }
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let zero_address = Zero::zero();
            assert(owner != zero_address, 'ERC: approve from 0');
            assert(spender != zero_address, 'ERC: approve to 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner: owner, spender: spender, value: amount });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256) {

            self.balance.write(to, self.balance.read(to) + amount);
            self.total_supply.write(self.total_supply.read() + amount);
            self.emit(Transfer{ from:Zero::zero(), to: to, value: amount});
        }
    }
}