use starknet::ContractAddress;
use starknet::storage::*;

// Define the structure to hold institution data
#[derive(Drop, Serde, starknet::Store)]
pub struct InstitutionData {
    pub name: ByteArray,
    pub license_id: ByteArray,
    pub metadata: ByteArray,
    pub is_verified: bool,
    pub is_registered: bool,
}

pub mod RegistryErrors {
    pub const INSTITUTION_ALREADY_REGISTERED: felt252 = 'InstitutionAlreadyRegistered';
    pub const INSTITUTION_NOT_REGISTERED: felt252 = 'InstitutionNotRegistered';
    pub const NOT_AUTHORIZED: felt252 = 'NotAuthorized';
    pub const INVALID_AMOUNT: felt252 = 'TGN: invalid amount!';
}


// Define the contract interface
#[starknet::interface]
pub trait IInstitutionRegistry<TContractState> {
    /// Registers a new healthcare institution.
    fn register_institution(
        ref self: TContractState,
        wallet: ContractAddress,
        name: ByteArray,
        license_id: ByteArray,
        metadata: ByteArray
    );

    /// Retrieves the stored data for a healthcare institution.
    fn get_institution(self: @TContractState, wallet: ContractAddress) -> InstitutionData;

    /// Updates the metadata for an already registered institution.
    fn update_institution(ref self: TContractState, wallet: ContractAddress, new_metadata: ByteArray);

    /// Flags or verifies an institution's credentials.
    fn verify_institution(ref self: TContractState, wallet: ContractAddress);

    /// Sets the authority address (only callable by the current authority/owner).
    fn set_authority(ref self: TContractState, new_authority: ContractAddress);

    /// Returns the current authority address.
    fn get_authority(self: @TContractState) -> ContractAddress;
}

// Define the contract module
#[starknet::contract]
pub mod InstitutionRegistry {
    use super::{InstitutionData, RegistryErrors};
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;

    // Define storage variables
    #[storage]
    pub struct Storage {
        // Mapping from institution wallet address to their data
        institutions: Map<ContractAddress, InstitutionData>,
        // Address authorized to perform sensitive operations like verification
        authority: ContractAddress,
    }

    // Constructor to set the initial authority
    #[constructor]
    fn constructor(ref self: ContractState, initial_authority: ContractAddress) {
        self.authority.write(initial_authority);
    }

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl InstitutionRegistryImpl of super::IInstitutionRegistry<ContractState> {
        // Registers a new healthcare institution
        fn register_institution(
            ref self: ContractState,
            wallet: ContractAddress,
            name: ByteArray,
            license_id: ByteArray,
            metadata: ByteArray
        ) {

            // Check: Ensure the institution is not already registered
            let existing_data = self.institutions.read(wallet);
            assert(!existing_data.is_registered, RegistryErrors::INSTITUTION_ALREADY_REGISTERED);

            // Create the institution data struct
            let institution_data = InstitutionData {
                name,
                license_id,
                metadata,
                is_verified: false, // Initially not verified
                is_registered: true,
            };

            // Write the data to storage using the wallet address as the key
            self.institutions.write(wallet, institution_data);
        }

        // Retrieves the stored data for a healthcare institution
        fn get_institution(self: @ContractState, wallet: ContractAddress) -> InstitutionData {
            // Read the data from storage using the wallet address
            self.institutions.read(wallet)
        }

        // Updates the metadata for an already registered institution
        fn update_institution(
            ref self: ContractState, wallet: ContractAddress, new_metadata: ByteArray
        ) {
            // Read the existing institution data
            let mut institution_data = self.institutions.read(wallet);
            assert(institution_data.is_registered, RegistryErrors::INSTITUTION_NOT_REGISTERED);

            // Update the metadata field
            institution_data.metadata = new_metadata;

            // Write the updated data back to storage
            self.institutions.write(wallet, institution_data);
        }

        // Flags or verifies an institution's credentials
        fn verify_institution(ref self: ContractState, wallet: ContractAddress) {
            // Check: Ensure the caller is the authorized authority
            let caller = get_caller_address();
            let authority = self.authority.read();
            // Corrected assert usage for felt252 error code
            assert(caller == authority, RegistryErrors::NOT_AUTHORIZED);
            // Read the existing institution data
            let mut institution_data = self.institutions.read(wallet);
            assert(institution_data.is_registered, RegistryErrors::INSTITUTION_NOT_REGISTERED);

            // Set the verification status to true
            institution_data.is_verified = true;

            // Write the updated data back to storage
            self.institutions.write(wallet, institution_data);
        }

        fn set_authority(ref self: ContractState, new_authority: ContractAddress) {
            // Check: Ensure the caller is the current authorized authority
            let caller = get_caller_address();
            let current_authority = self.authority.read();
            // Corrected assert usage for felt252 error code
            assert(caller == current_authority, RegistryErrors::NOT_AUTHORIZED); 

            // Effects: Update the authority storage variable
            self.authority.write(new_authority); // [7]
        }

        // Returns the current authority address
        fn get_authority(self: @ContractState) -> ContractAddress {
            self.authority.read() // [7]
        }
    }
}