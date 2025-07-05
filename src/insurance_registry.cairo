use starknet::ContractAddress;
use starknet::storage::*;

// Define the structure to hold insurer data
#[derive(Drop, Serde, starknet::Store)]
pub struct InsurerData {
    pub name: ByteArray,
    pub license_id: ByteArray,
    pub metadata: ByteArray,
    pub is_registered: bool,
}

pub mod InsuranceErrors {
    pub const INSURER_ALREADY_REGISTERED: felt252 = 'InsurerAlreadyRegistered';
    pub const INSURER_NOT_REGISTERED: felt252 = 'InsurerNotRegistered';
}

// Define the contract interface
#[starknet::interface]
pub trait IInsuranceRegistry<TContractState> {
    /// Registers a new insurer with the given wallet address, name, license ID, and metadata.
    fn register_insurer(
        ref self: TContractState,
        wallet: ContractAddress,
        name: ByteArray,
        license_id: ByteArray,
        metadata: ByteArray,
    );

    /// Updates the metadata for an existing insurer associated with the provided wallet address.
    fn update_insurer(ref self: TContractState, wallet: ContractAddress, metadata: ByteArray);

    /// Retrieves the insurer data for the specified wallet address.
    fn get_insurer(self: @TContractState, wallet: ContractAddress) -> InsurerData;
}

// Define the contract module
#[starknet::contract]
pub mod InsuranceRegistry {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use super::{InsuranceErrors, InsurerData};

    // Define storage variables
    #[storage]
    pub struct Storage {
        // Mapping from insurer wallet address to their data
        insurers: Map<ContractAddress, InsurerData>,
    }

    // Constructor (empty for this contract)
    #[constructor]
    fn constructor(ref self: ContractState) {}

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl InsuranceRegistryImpl of super::IInsuranceRegistry<ContractState> {
        // Registers a new insurer
        fn register_insurer(
            ref self: ContractState,
            wallet: ContractAddress,
            name: ByteArray,
            license_id: ByteArray,
            metadata: ByteArray,
        ) {
            // Check: Ensure the insurer is not already registered
            let existing_data = self.insurers.read(wallet);
            assert(!existing_data.is_registered, InsuranceErrors::INSURER_ALREADY_REGISTERED);

            // Create the insurer data struct
            let insurer_data = InsurerData { name, license_id, metadata, is_registered: true };

            // Write the data to storage using the wallet address as the key
            self.insurers.write(wallet, insurer_data);
        }

        // Updates the metadata for an existing insurer
        fn update_insurer(ref self: ContractState, wallet: ContractAddress, metadata: ByteArray) {
            // Read the existing insurer data
            let mut insurer_data = self.insurers.read(wallet);
            assert(insurer_data.is_registered, InsuranceErrors::INSURER_NOT_REGISTERED);

            // Update the metadata field
            insurer_data.metadata = metadata;

            // Write the updated data back to storage
            self.insurers.write(wallet, insurer_data);
        }

        // Retrieves the insurer data for the specified wallet address
        fn get_insurer(self: @ContractState, wallet: ContractAddress) -> InsurerData {
            // Read the data from storage using the wallet address
            self.insurers.read(wallet)
        }
    }
}
