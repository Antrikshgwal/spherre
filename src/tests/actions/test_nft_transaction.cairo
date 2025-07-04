use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, StarknetEnv, Uint256Assertions, deploy, start_prank, stop_prank, cheatcodes, ContractClass
};
use spherre::interfaces::ierc721::{IERC721Dispatcher};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use spherre::tests::mocks::mock_nft::{IMockNFTDispatcher, IMockNFTDispatcherTrait};

use spherre::types::{TransactionType};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_nft() -> IERC721Dispatcher {
    let contract_class = declare("MockNFT").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC721Dispatcher { contract_address }
}

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn recipient() -> ContractAddress {
    contract_address_const::<'recipient'>()
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

#[test]
fn test_propose_nft_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::NFT_SEND, 'Invalid Transaction');
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft_contract.contract_address, 'NFT Contract Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient Invalid');
}


#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_nft_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member but do not assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_propose_nft_transaction_fail_if_not_owner() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    let other_account: ContractAddress = contract_address_const::<'other'>();

    // Mint NFT to a different account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(other_account, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_nft_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'NFT contract address is zero')]
fn test_propose_nft_transaction_fail_if_nft_contract_zero() {
    let mock_contract = deploy_mock_contract();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero NFT contract address
    mock_contract.propose_nft_transaction_pub(zero_address(), token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_propose_nft_transaction_fail_if_recipient_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero recipient address
    mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, zero_address());
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token ID is invalid')]
fn test_propose_nft_transaction_fail_if_token_id_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 0;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, 1); // Mint a different token ID

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero token ID
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid token ID')]
fn test_propose_nft_transaction_fail_if_token_id_non_existent() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Do not mint the token ID
    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with non-existent token ID
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_propose_nft_transaction_fail_if_paused() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Pause the contract
    mock_contract.pause();

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid NFT transaction')]
fn test_get_nft_transaction_fail_if_invalid_type() {
    let mock_contract = deploy_mock_contract();
    let caller: ContractAddress = owner();

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Create a TOKEN_SEND transaction
    let tx_id = mock_contract.create_transaction_pub(TransactionType::TOKEN_SEND);

    // Attempt to retrieve as NFT transaction (should fail)
    mock_contract.get_nft_transaction_pub(tx_id);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Transaction is out of range')]
fn test_get_nft_transaction_fail_if_non_existent() {
    let mock_contract = deploy_mock_contract();
    let _caller: ContractAddress = owner();

    // Attempt to retrieve a non-existent transaction
    mock_contract.get_nft_transaction_pub(999);
    stop_cheat_caller_address(mock_contract.contract_address);
}

    #[test]
    fn test_execute_with_sufficient_approvals() {

    call!(account, tx_contract.add_member(account.address())).assert_success();
    call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();

        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 1_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();

        let recipient = env.get_account(1).address();
        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        call!(account, tx_contract.approve_transaction(tx_id)).assert_success();

        call!(account, tx_contract.execute_nft_transaction(tx_id)).assert_success();

        let owner = call!(account, nft_contract.owner_of(token_id)).unwrap();
        assert_eq!(owner, recipient);
    }

    #[test]
    fn test_execute_fails_without_approvals() {

        call!(account, tx_contract.add_member(account.address())).assert_success();
        call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();

        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 2_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();

        let recipient = env.get_account(1).address();
        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        let result = call!(account, tx_contract.execute_nft_transaction(tx_id));
        assert!(result.is_err());
    }

    #[test]
    fn test_execute_twice_should_fail() {

        call!(account, tx_contract.add_member(account.address())).assert_success();
        call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();

        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 3_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();
        let recipient = env.get_account(1).address();

        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        call!(account, tx_contract.approve_transaction(tx_id)).assert_success();
        call!(account, tx_contract.execute_nft_transaction(tx_id)).assert_success();

        let result = call!(account, tx_contract.execute_nft_transaction(tx_id));
        assert!(result.is_err());
    }

    #[test]
    fn test_execute_canceled_transaction_should_fail() {

        call!(account, tx_contract.add_member(account.address())).assert_success();
        call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();


        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 4_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();
        let recipient = env.get_account(1).address();

        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        call!(account, tx_contract.cancel_transaction(tx_id)).assert_success();

        let result = call!(account, tx_contract.execute_nft_transaction(tx_id));
        assert!(result.is_err());
    }

    #[test]
    fn test_non_executor_cannot_execute() {

        call!(account, tx_contract.add_member(account.address())).assert_success();
        call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();

        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let attacker = env.get_account(2);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 5_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();
        let recipient = env.get_account(1).address();

        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        call!(account, tx_contract.approve_transaction(tx_id)).assert_success();

        let result = call!(attacker, tx_contract.execute_nft_transaction(tx_id));
        assert!(result.is_err());
    }

    #[test]
    fn test_event_emitted_on_execution() {

        call!(account, tx_contract.add_member(account.address())).assert_success();
        call!(account, tx_contract.assign_proposer_permission(account.address())).assert_success();

        let env = StarknetEnv::new();
        let account = env.get_account(0);
        let nft_contract = deploy!(env, "MockERC721" {});
        let tx_contract = deploy!(env, "NFTTransaction" {});

        let token_id = 6_u256;
        call!(account, nft_contract.mint(account.address(), token_id)).assert_success();
        let recipient = env.get_account(1).address();

        let tx_id = call!(account, tx_contract.propose_nft_transaction(
            nft_contract.contract_address(),
            token_id,
            recipient
        )).unwrap();

        call!(account, tx_contract.approve_transaction(tx_id)).assert_success();
        let exec_result = call!(account, tx_contract.execute_nft_transaction(tx_id));
        exec_result.assert_success();

        let logs = env.read_events();
        assert!(logs.contains_event("NFTTransactionExecuted"));
    }
}
