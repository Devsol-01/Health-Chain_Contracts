use health_chain_contracts::healthcare_registration::{
    IInstitutionRegistryDispatcher, IInstitutionRegistryDispatcherTrait,
    IInstitutionRegistrySafeDispatcher, IInstitutionRegistrySafeDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_institution_registry(
    initial_authority: ContractAddress,
) -> IInstitutionRegistryDispatcher {
    let contract = declare("InstitutionRegistry");
    let mut constructor_calldata = array![
        initial_authority.into(),
    ]; // Pass authority to constructor [2]
    let (contract_address, _err) = contract
        .unwrap()
        .contract_class()
        .deploy(@constructor_calldata)
        .unwrap();
    IInstitutionRegistryDispatcher { contract_address }
}

#[test]
fn test_register_institution() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    // Define test data
    let institution_wallet: ContractAddress = 123.try_into().unwrap();
    let name = "MyHospital";
    let license_id = "LIC123";
    let metadata = "some metadata";

    dispatcher
        .register_institution(
            institution_wallet.clone(), name.clone(), license_id.clone(), metadata.clone(),
        );

    // Retrieve the data
    let stored_data = dispatcher.get_institution(institution_wallet);

    // Assert the stored data matches the input and is_verified is false initially
    assert(stored_data.name == name, 'Wrong name');
    assert(stored_data.license_id == license_id, 'Wrong license_id');
    assert(stored_data.metadata == metadata, 'Wrong metadata');
    assert(stored_data.is_verified == false, 'Institution not verified');
}

#[test]
fn test_get_non_existent_institution() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);
    let non_existent_wallet: ContractAddress = 456.try_into().unwrap();

    let stored_data = dispatcher.get_institution(non_existent_wallet);

    assert(stored_data.name == "", 'Name should be default');
    assert(stored_data.license_id == "", 'License_id should be default');
    assert(stored_data.metadata == "", 'Metadata should be default');
    assert(!stored_data.is_verified, 'Is_verified should be default');
}

#[test]
fn test_update_institution_metadata() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let institution_wallet: ContractAddress = 789.try_into().unwrap();
    let name = "MyHospital";
    let license_id = "OLDLIC";
    let initial_metadata = "initial metadata";
    let new_metadata = "updated metadata";

    dispatcher
        .register_institution(
            institution_wallet, name.clone(), license_id.clone(), initial_metadata.clone(),
        );

    dispatcher.update_institution(institution_wallet, new_metadata.clone());

    let stored_data = dispatcher.get_institution(institution_wallet);

    assert(stored_data.name == name, 'Name changed unexpectedly');
    assert(stored_data.license_id == license_id, 'License_id changed unexpectedly');
    assert(stored_data.metadata == new_metadata, 'Metadata was not updated');
    assert(!stored_data.is_verified, 'Is_verified changed');
}

#[test]
#[should_panic(expected: 'InstitutionAlreadyRegistered')]
fn test_register_institution_duplicate() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let institution_wallet: ContractAddress = 123.try_into().unwrap();
    let name = "MyHospital";
    let license_id = "LIC123";
    let metadata = "some metadata";

    // Register the institution the first time (should succeed)
    dispatcher
        .register_institution(
            institution_wallet.clone(), name.clone(), license_id.clone(), metadata.clone(),
        );

    // Attempt to register the same institution again (should panic)
    dispatcher.register_institution(institution_wallet, name, license_id, metadata);
}

#[test]
#[should_panic(
    expected: 'InstitutionNotRegistered',
)] // Expect a panic if institution not registered [3]
fn test_update_institution_metadata_not_registered() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let non_existent_wallet: ContractAddress = 456.try_into().unwrap();
    let new_metadata = "updated metadata";

    // Attempt to update metadata for a non-existent institution (should panic)
    dispatcher.update_institution(non_existent_wallet, new_metadata);
}

#[test]
#[should_panic(
    expected: 'InstitutionNotRegistered',
)] // Expect a panic if institution not registered [3]
fn test_verify_institution_not_registered() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let non_existent_wallet: ContractAddress = 456.try_into().unwrap();
    let authority: ContractAddress = initial_authority; // Use the authority address

    // Cheat the caller address to be the authority [3]
    start_cheat_caller_address(dispatcher.contract_address, authority);

    // Attempt to verify a non-existent institution (should panic)
    dispatcher.verify_institution(non_existent_wallet);

    stop_cheat_caller_address(dispatcher.contract_address); // Stop cheating [3]
}


#[test]
#[should_panic(expected: 'NotAuthorized')] // Expect a panic if caller is not authorized [3]
fn test_verify_institution_unauthorized() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let institution_wallet: ContractAddress = 123.try_into().unwrap();
    let name = "MyHospital";
    let license_id = "LIC123";
    let metadata = "some metadata";

    dispatcher.register_institution(institution_wallet, name, license_id, metadata);

    let unauthorized_caller: ContractAddress = 999.try_into().unwrap();

    // Cheat the caller address to be unauthorized
    start_cheat_caller_address(dispatcher.contract_address, unauthorized_caller);

    // Attempt to verify the institution as an unauthorized caller (should panic)
    dispatcher.verify_institution(institution_wallet);

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'NotAuthorized')] // Expect a panic if caller is not authorized [3]
fn test_set_authority_unauthorized() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let unauthorized_caller: ContractAddress = 999.try_into().unwrap();
    let new_authority: ContractAddress = 2000.try_into().unwrap();

    // Cheat the caller address to be unauthorized [3]
    start_cheat_caller_address(dispatcher.contract_address, unauthorized_caller);

    // Attempt to set new authority as an unauthorized caller (should panic)
    dispatcher.set_authority(new_authority);

    stop_cheat_caller_address(dispatcher.contract_address); // Stop cheating [3]
}

#[test]
fn test_set_authority_authorized() {
    let initial_authority: ContractAddress = 1000.try_into().unwrap();
    let dispatcher = deploy_institution_registry(initial_authority);

    let new_authority: ContractAddress = 2000.try_into().unwrap();

    // Check initial authority
    assert(dispatcher.get_authority() == initial_authority, 'Initial authority incorrect');

    // Cheat the caller address to be the current authority [3]
    start_cheat_caller_address(dispatcher.contract_address, initial_authority);

    // Set new authority as the authorized caller (should succeed)
    dispatcher.set_authority(new_authority);

    stop_cheat_caller_address(dispatcher.contract_address); // Stop cheating [3]

    // Check updated authority
    assert(dispatcher.get_authority() == new_authority, 'Authority not updated');
}
