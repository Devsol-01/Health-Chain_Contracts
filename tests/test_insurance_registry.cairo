use health_chain_contracts::insurance_registry::{
    IInsuranceRegistryDispatcher, IInsuranceRegistryDispatcherTrait,
    IInsuranceRegistrySafeDispatcher, IInsuranceRegistrySafeDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_insurance_registry() -> IInsuranceRegistryDispatcher {
    let contract = declare("InsuranceRegistry");
    let (contract_address, _err) = contract
        .unwrap()
        .contract_class()
        .deploy(@ArrayTrait::new())
        .unwrap();
    IInsuranceRegistryDispatcher { contract_address }
}

#[test]
fn test_register_insurer() {
    let dispatcher = deploy_insurance_registry();

    // Define test data
    let insurer_wallet: ContractAddress = 123.try_into().unwrap();
    let name = "BlueCross Insurance";
    let license_id = "INS123";
    let metadata = "Contact: info@bluecross.com, Coverage: Health, Dental, Vision";

    dispatcher
        .register_insurer(
            insurer_wallet.clone(), name.clone(), license_id.clone(), metadata.clone(),
        );

    // Retrieve the data
    let stored_data = dispatcher.get_insurer(insurer_wallet);

    // Assert the stored data matches the input
    assert(stored_data.name == name, 'Wrong name');
    assert(stored_data.license_id == license_id, 'Wrong license_id');
    assert(stored_data.metadata == metadata, 'Wrong metadata');
    assert(stored_data.is_registered == true, 'Insurer not registered');
}

#[test]
fn test_get_non_existent_insurer() {
    let dispatcher = deploy_insurance_registry();
    let non_existent_wallet: ContractAddress = 456.try_into().unwrap();

    let stored_data = dispatcher.get_insurer(non_existent_wallet);

    // For non-existent insurers, we get default values
    assert(stored_data.name == "", 'Name should be default');
    assert(stored_data.license_id == "", 'License_id should be default');
    assert(stored_data.metadata == "", 'Metadata should be default');
    assert(!stored_data.is_registered, 'Is_registered should be default');
}

#[test]
fn test_update_insurer_metadata() {
    let dispatcher = deploy_insurance_registry();

    let insurer_wallet: ContractAddress = 789.try_into().unwrap();
    let name = "Aetna Insurance";
    let license_id = "AET456";
    let initial_metadata = "Contact: info@aetna.com, Coverage: Health";
    let new_metadata = "Contact: support@aetna.com, Coverage: Health, Dental, Vision, Life";

    dispatcher
        .register_insurer(
            insurer_wallet, name.clone(), license_id.clone(), initial_metadata.clone(),
        );

    dispatcher.update_insurer(insurer_wallet, new_metadata.clone());

    let stored_data = dispatcher.get_insurer(insurer_wallet);

    assert(stored_data.name == name, 'Name changed unexpectedly');
    assert(stored_data.license_id == license_id, 'License_id changed unexpectedly');
    assert(stored_data.metadata == new_metadata, 'Metadata was not updated');
    assert(stored_data.is_registered == true, 'Registration status changed');
}

#[test]
#[should_panic(expected: 'InsurerAlreadyRegistered')]
fn test_register_insurer_duplicate() {
    let dispatcher = deploy_insurance_registry();

    let insurer_wallet: ContractAddress = 123.try_into().unwrap();
    let name = "Cigna Insurance";
    let license_id = "CIG789";
    let metadata = "Contact: info@cigna.com, Coverage: Health, Dental";

    // Register the insurer the first time (should succeed)
    dispatcher
        .register_insurer(
            insurer_wallet.clone(), name.clone(), license_id.clone(), metadata.clone(),
        );

    // Attempt to register the same insurer again (should panic)
    dispatcher.register_insurer(insurer_wallet, name, license_id, metadata);
}

#[test]
#[should_panic(expected: 'InsurerNotRegistered')]
fn test_update_insurer_metadata_not_registered() {
    let dispatcher = deploy_insurance_registry();

    let non_existent_wallet: ContractAddress = 456.try_into().unwrap();
    let new_metadata = "Updated metadata";

    // Attempt to update metadata for a non-existent insurer (should panic)
    dispatcher.update_insurer(non_existent_wallet, new_metadata);
}

#[test]
fn test_multiple_insurers() {
    let dispatcher = deploy_insurance_registry();

    // Register first insurer
    let insurer1_wallet: ContractAddress = 100.try_into().unwrap();
    let name1 = "UnitedHealth";
    let license1 = "UNH001";
    let metadata1 = "Contact: info@unitedhealth.com";

    // Register second insurer
    let insurer2_wallet: ContractAddress = 200.try_into().unwrap();
    let name2 = "Humana";
    let license2 = "HUM002";
    let metadata2 = "Contact: info@humana.com";

    dispatcher
        .register_insurer(insurer1_wallet, name1.clone(), license1.clone(), metadata1.clone());
    dispatcher
        .register_insurer(insurer2_wallet, name2.clone(), license2.clone(), metadata2.clone());

    // Retrieve both insurers
    let stored_data1 = dispatcher.get_insurer(insurer1_wallet);
    let stored_data2 = dispatcher.get_insurer(insurer2_wallet);

    // Verify first insurer data
    assert(stored_data1.name == name1, 'Wrong name for insurer 1');
    assert(stored_data1.license_id == license1, 'Wrong license for insurer 1');
    assert(stored_data1.metadata == metadata1, 'Wrong metadata for insurer 1');
    assert(stored_data1.is_registered == true, 'Insurer 1 not registered');

    // Verify second insurer data
    assert(stored_data2.name == name2, 'Wrong name for insurer 2');
    assert(stored_data2.license_id == license2, 'Wrong license for insurer 2');
    assert(stored_data2.metadata == metadata2, 'Wrong metadata for insurer 2');
    assert(stored_data2.is_registered == true, 'Insurer 2 not registered');
}

#[test]
fn test_update_insurer_multiple_times() {
    let dispatcher = deploy_insurance_registry();

    let insurer_wallet: ContractAddress = 300.try_into().unwrap();
    let name = "Kaiser Permanente";
    let license_id = "KP003";
    let initial_metadata = "Contact: info@kaiser.com";
    let updated_metadata1 = "Contact: info@kaiser.com, Coverage: Health, Dental";
    let updated_metadata2 =
        "Contact: info@kaiser.com, Coverage: Health, Dental, Vision, Mental Health";

    // Register insurer
    dispatcher
        .register_insurer(
            insurer_wallet, name.clone(), license_id.clone(), initial_metadata.clone(),
        );

    // Update metadata first time
    dispatcher.update_insurer(insurer_wallet, updated_metadata1.clone());
    let stored_data1 = dispatcher.get_insurer(insurer_wallet);
    assert(stored_data1.metadata == updated_metadata1, 'First update failed');

    // Update metadata second time
    dispatcher.update_insurer(insurer_wallet, updated_metadata2.clone());
    let stored_data2 = dispatcher.get_insurer(insurer_wallet);
    assert(stored_data2.metadata == updated_metadata2, 'Second update failed');
    assert(stored_data2.name == name, 'Name changed unexpectedly');
    assert(stored_data2.license_id == license_id, 'License changed unexpectedly');
}
